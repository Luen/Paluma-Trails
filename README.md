# Paluma-Trails

Paluma-Trails is a project concept for a website and Flutter mobile app to help
people explore Paluma Range National Park. It aims to make useful trail
information available before and during a walk, including when there is no
mobile reception.

## What it could offer

- **Custom trail maps:** Show the park's track network, junctions, points of
  interest, and useful trail details. Include distances and estimated walking
  times between junctions so hikers can plan a route and understand what lies
  ahead.
- **Offline access:** THe app should auto download maps and information before
  setting out, then use them on the trail without an internet connection.
- **QR-code points of interest:** Let visitors scan codes at selected places
  along the tracks to learn more about the area. Possible stops include the tin
  mines and Garde's Hut Clearing. Information could include the site's history,
  natural features, and visitor guidance. Needs to be offline use. Also show the
  POIs on the map and allow users to click that icon for more information as well.
- **Track issue reports:** Make it easy to report hazards such as fallen trees,
  damaged signs, or track obstructions, with a description and optional location
  or photo. Possibly show on the map when that track was last maintain...
- **Offline-first reporting:** Save reports on the device when offline and send
  them automatically once an internet connection is available. Show whether a
  report is waiting to send or has been submitted, so hikers know it has not
  been lost.
- **Weather:** Upcoming weather for the weekend. BOM Weather as the source. 

## A possible visitor journey

Before a walk, a visitor checks the website or they download the app. The app 
would auto downloads the relevant map in the app. On the track, they follow 
the map and use junction distances and walking-time estimates to make route 
decisions. At a marked location, they scan its QR code for additional 
information (and historic photos). If they find a problem, they record it in 
the app; the report is queued offline and synced later, helping the team 
identify and clear hazards.

## Ideas to explore

- Keep map and POI content maintainable so updates can be packaged for offline
  use. Possibly a git tracked JSON file.
- Clearly distinguish estimated walking times from guaranteed timings, and
  provide practical safety and park-condition guidance.
- Make reports useful to the team by capturing only relevant details and
  indicating when and where an issue was observed.
- Design the app for use outdoors, including readable maps and controls that
  are easy to use while walking.

These are intended goals and ideas for the project, not a statement that these
features are already implemented.

Current maps:
<img width="1051" height="1364" alt="image" src="https://github.com/user-attachments/assets/a5cd5ebf-65e4-4135-aae7-9bc9fa62f9f9" />
<img width="1321" height="925" alt="image" src="https://github.com/user-attachments/assets/b40fe328-3310-4d86-ad26-1f27b8020587" />
<img width="1312" height="918" alt="image" src="https://github.com/user-attachments/assets/ff219042-b02b-4f21-b4cb-da4556bef134" />

More information: 
https://wanderstories.space/paluma-maps/
https://wanderstories.space/hiking-at-paluma-range-national-park/
See also: http://paluma.org/
