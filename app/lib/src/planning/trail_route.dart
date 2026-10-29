import '../content/bundle_repository.dart';
import '../content/models.dart';

/// How a planned walk gets back to where it started.
enum WalkShape {
  /// Finish somewhere else.
  oneWay,

  /// Walk to the other junction and return by the same tracks.
  outAndBack,

  /// Leave a junction and come back to it by a different way.
  loop,
}

/// One junction-to-junction stretch of a planned walk.
class RouteLeg {
  const RouteLeg({required this.from, required this.to, required this.segment});

  /// Junction ids, not labels: the UI resolves labels from the bundle so a
  /// content rename never leaves a stale route behind.
  final String from;
  final String to;
  final Segment segment;

  int get distanceM => segment.distanceM;
  int get walkMinutes => segment.walkMinutes;

  /// The track this leg follows, or `Connector` for a segment with no name.
  String get trackName =>
      segment.trackName.isEmpty ? 'Connector' : segment.trackName;
}

/// A walk across the bundle's junction graph.
///
/// Only mapped, connected segments are used, so the totals describe the tracks
/// the park data actually has. Nothing here reaches the network, and nothing
/// here invents a shortcut across the scrub.
class TrailRoute {
  const TrailRoute({
    required this.startId,
    required this.endId,
    required this.legs,
    this.shape = WalkShape.oneWay,
  });

  final String startId;
  final String endId;
  final List<RouteLeg> legs;
  final WalkShape shape;

  bool get isLoop => shape == WalkShape.loop;
  bool get returnsSameWay => shape == WalkShape.outAndBack;

  /// Junctions in walking order, starting at [startId].
  List<String> get junctionIds => [startId, for (final leg in legs) leg.to];

  /// Distance of the walk as planned, including the return leg of an out-and-
  /// back.
  int get distanceM => _oneWayDistanceM * (returnsSameWay ? 2 : 1);

  /// Estimated walking time, including the return leg of an out-and-back.
  int get walkMinutes => _oneWayWalkMinutes * (returnsSameWay ? 2 : 1);

  /// One direction, which is what the itinerary lists.
  int get oneWayDistanceM => _oneWayDistanceM;

  int get oneWayWalkMinutes => _oneWayWalkMinutes;

  int get _oneWayDistanceM => legs.fold(0, (sum, leg) => sum + leg.distanceM);

  int get _oneWayWalkMinutes =>
      legs.fold(0, (sum, leg) => sum + leg.walkMinutes);
}

/// Plans a walk over the mapped junctions, or null when the content has no
/// connected route.
///
/// The shortest route is chosen by distance, not by estimated time, because
/// the two can disagree at a junction where a road shortcut is faster than a
/// longer walking track; walkers expect the shortest path when they ask for
/// one.
TrailRoute? planWalk(
  LoadedBundle bundle, {
  required String fromId,
  required String toId,
  WalkShape shape = WalkShape.oneWay,
}) {
  if (!bundle.junctions.containsKey(fromId)) return null;
  final graph = _buildGraph(bundle);

  if (shape == WalkShape.loop) {
    final legs = _shortestLoop(graph, fromId);
    if (legs == null) return null;
    return TrailRoute(
      startId: fromId,
      endId: fromId,
      legs: legs,
      shape: WalkShape.loop,
    );
  }

  if (fromId == toId || !bundle.junctions.containsKey(toId)) return null;
  final legs = _shortestPath(graph, fromId, toId);
  if (legs == null) return null;
  return TrailRoute(startId: fromId, endId: toId, legs: legs, shape: shape);
}

class _Edge {
  const _Edge({required this.to, required this.segment});

  final String to;
  final Segment segment;
}

/// Undirected junction graph. A segment can be walked either way, so each one
/// becomes two edges pointing at the same content record.
Map<String, List<_Edge>> _buildGraph(LoadedBundle bundle) {
  final graph = <String, List<_Edge>>{};
  for (final segment in bundle.segments) {
    if (!bundle.junctions.containsKey(segment.from)) continue;
    if (!bundle.junctions.containsKey(segment.to)) continue;
    graph
        .putIfAbsent(segment.from, () => [])
        .add(_Edge(to: segment.to, segment: segment));
    graph
        .putIfAbsent(segment.to, () => [])
        .add(_Edge(to: segment.from, segment: segment));
  }
  return graph;
}

/// Dijkstra, with the whole park's junction count in the tens, so the simple
/// scan for the nearest unvisited node is cheaper than a heap.
List<RouteLeg>? _shortestPath(
  Map<String, List<_Edge>> graph,
  String from,
  String to, {
  Segment? banned,
}) {
  final nodes = graph.keys.toList()..sort();
  final distance = <String, int>{for (final node in nodes) node: _unreachable};
  final previous = <String, _Edge>{};
  final visited = <String>{};
  distance[from] = 0;

  while (true) {
    String? current;
    var best = _unreachable;
    for (final node in nodes) {
      if (visited.contains(node)) continue;
      final value = distance[node]!;
      if (value < best) {
        best = value;
        current = node;
      }
    }
    if (current == null || best == _unreachable) break;
    if (current == to) break;
    visited.add(current);

    for (final edge in graph[current] ?? const <_Edge>[]) {
      if (identical(edge.segment, banned)) continue;
      if (visited.contains(edge.to)) continue;
      final candidate = distance[current]! + edge.segment.distanceM;
      if (candidate < distance[edge.to]!) {
        distance[edge.to] = candidate;
        previous[edge.to] = _Edge(to: current, segment: edge.segment);
      }
    }
  }

  final target = distance[to];
  if (target == null || target == _unreachable) return null;

  final legs = <RouteLeg>[];
  var node = to;
  while (node != from) {
    final edge = previous[node];
    if (edge == null) return null;
    legs.add(RouteLeg(from: edge.to, to: node, segment: edge.segment));
    node = edge.to;
  }
  return legs.reversed.toList(growable: false);
}

/// The shortest way out of [start] and back, trying every first hop so a
/// cycle that leaves by a long track and returns on a short one is still
/// found.
List<RouteLeg>? _shortestLoop(Map<String, List<_Edge>> graph, String start) {
  List<RouteLeg>? best;
  var bestDistance = _unreachable;

  for (final edge in graph[start] ?? const <_Edge>[]) {
    final back = _shortestPath(graph, edge.to, start, banned: edge.segment);
    if (back == null) continue;
    // Two legs over the same pair of junctions is an out-and-back on parallel
    // tracks, not a loop a walker would plan.
    if (back.length < 2) continue;
    final total =
        edge.segment.distanceM +
        back.fold<int>(0, (sum, leg) => sum + leg.distanceM);
    if (total < bestDistance) {
      bestDistance = total;
      best = [
        RouteLeg(from: start, to: edge.to, segment: edge.segment),
        ...back,
      ];
    }
  }

  return best;
}

/// Larger than any real park route, so "unvisited" needs no null checks in the
/// hot loop.
const _unreachable = 1 << 30;
