/*
  ISOTOPES LACROSSE — SITE DATA
  ------------------------------------------------------------
  Edit the arrays below to update the site. No HTML editing needed
  for roster, schedule, events, juniors info, or gallery photos.

  - ROSTER: add/remove players. `photo` can point to a real headshot
    in /assets/img/roster/ — leave null to show the jersey-number tile.
  - STAFF: coaches/front office, shown on roster.html.
  - SEASON_HISTORY: past-season results by year, shown on schedule.html.
  - SCHEDULE: Senior game list. `oppLogo` can point to a team logo in
    /assets/img/opponents/ (e.g. "assets/img/opponents/blueshirts.png")
    — leave null to show just the opponent name with no logo.
  - EVENTS: non-game team events (banquets, clinics, fundraisers, etc).
    Shown together with SCHEDULE on schedule.html.
  - JUNIORS_SCHEDULE: Isotopes Juniors is a youth league the Isotopes
    organize and run at VMCC (not a traveling team), so entries are
    events (Tryouts, Game 1, Championship, etc.), not opponents.
  - JUNIORS_LOCATIONS: juniors.html location cards.
  - GALLERY: photo gallery. `category` = "senior" | "juniors" | "events".
*/

const ROSTER = [
  { id: 1, number: 78, name: "Brenden Bloedel", position: "Forward", height: "5'11\"", weight: 185, hometown: "Cottage Grove, MN", photo: null },
  { id: 2, number: 32, name: "Jaydan Buck", position: "Transition", height: "5'10\"", weight: 200, hometown: "Red Wing/Hudson, MN", photo: null },
  { id: 3, number: 34, name: "Miles Chism", position: "Defense", height: "5'9\"", weight: 180, hometown: "Hopkins, MN", photo: null },
  { id: 4, number: 94, name: "Jordan Chock", position: "Forward", height: "6'1\"", weight: 185, hometown: "Lonsdale, MN", photo: null },
  { id: 5, number: 35, name: "John Chorlton", position: "Transition", height: "6'0\"", weight: 205, hometown: "Hastings, MN", photo: null },
  { id: 6, number: 97, name: "Luke Chorlton", position: "Transition", height: "5'10\"", weight: 185, hometown: "Hastings, MN", photo: null },
  { id: 7, number: 22, name: "Victor Flores", position: "Forward", height: "5'10\"", weight: 260, hometown: "Inver Grove, MN", photo: null },
  { id: 8, number: 23, name: "Jimmy Garay-Triviski", position: "Defense", height: "5'10\"", weight: 240, hometown: "Oakdale, MN", photo: null },
  { id: 9, number: 14, name: "Charlie Gee", position: "Transition", height: "6'2\"", weight: 190, hometown: "Minneapolis, MN", photo: null },
  { id: 10, number: 88, name: "Beck Hagen", position: "Goalie", height: "5'11\"", weight: 160, hometown: "Hopkins, MN", photo: null },
  { id: 11, number: 44, name: "Josh Harris", position: "Goalie", height: "5'9\"", weight: 180, hometown: "Blaine, MN", photo: null },
  { id: 12, number: 93, name: "Talon Heath", position: "Forward", height: "5'10\"", weight: 185, hometown: "Elk River, MN", photo: null },
  { id: 13, number: 3, name: "Brody Illies", position: "Defense", height: "5'9\"", weight: 220, hometown: "New Prague, MN", photo: null },
  { id: 14, number: 92, name: "Bradley Johnson", position: "Forward", height: "5'10\"", weight: 160, hometown: "Cottage Grove, MN", photo: null },
  { id: 15, number: 84, name: "Lukas Johnson", position: "Forward", height: "6'2\"", weight: 220, hometown: "Inver Grove Heights, MN", photo: null },
  { id: 16, number: 64, name: "Gavin Krcil", position: "Defense", height: "6'5\"", weight: 230, hometown: "Hanover, MN", photo: null },
  { id: 17, number: 91, name: "Maxwell Krueger", position: "Transition", height: "5'10\"", weight: 180, hometown: "Hudson, WI", photo: null },
  { id: 18, number: 54, name: "Spencer Krueger", position: "Transition", height: "5'9\"", weight: 185, hometown: "Hudson, WI", photo: null },
  { id: 19, number: 11, name: "Jacob McCoy", position: "Forward", height: "6'1\"", weight: 210, hometown: "Chaska, MN", photo: null },
  { id: 20, number: 20, name: "James McDonald", position: "Forward", height: "6'3\"", weight: 200, hometown: "Saint Paul, MN", photo: null },
  { id: 21, number: 43, name: "Maxwell Olson-Burkman", position: "Defense", height: "6'1\"", weight: 210, hometown: "Becker, MN", photo: null },
  { id: 22, number: 0, name: "Daltin Pedersen", position: "Forward", height: "6'1\"", weight: 180, hometown: "Inver Grove Heights, MN", photo: null },
  { id: 23, number: 1, name: "Leyton Scribner", position: "Forward", height: "6'0\"", weight: 150, hometown: "Webster, MN", photo: null },
  { id: 24, number: 39, name: "Dawson Sheets", position: "Forward", height: "6'2\"", weight: 210, hometown: "Lakeville, MN", photo: null },
  { id: 25, number: 86, name: "Aidan Siegfried", position: "Transition", height: "5'11\"", weight: 185, hometown: "St. Paul, MN", photo: null },
  { id: 26, number: 47, name: "Jameson Stahl", position: "Defense", height: "6'5\"", weight: 220, hometown: "Stillwater, MN", photo: null },
  { id: 27, number: 55, name: "Jaston Tank", position: "Defense", height: "5'11\"", weight: 203, hometown: "Farmington, MN", photo: null },
  { id: 28, number: 12, name: "Dominic Thone", position: "Defense", height: "5'9\"", weight: 180, hometown: "The Shire, MN", photo: null },
  { id: 29, number: 65, name: "Hayden Ungs", position: "Forward", height: "5'10\"", weight: 155, hometown: "New Prague, MN", photo: null },
  { id: 30, number: 7, name: "Alex Wallis", position: "Defense", height: "5'11\"", weight: 205, hometown: "St. Paul, MN", photo: null },
  { id: 31, number: 16, name: "Sam Caron", position: "Transition", height: "6'3\"", weight: 205, hometown: "Saint Michael, MN", photo: null }
];

const STAFF = [
  { name: "Richard Chorlton", role: "Head Coach" },
  { name: "Rachel Anderson", role: "President" }
];

// Past season results, most recent year first. `home` reflects the
// designated home team for that game (not always the physical venue —
// see 2023-07-23, which was hosted at VMCC but Isotopes were away).
const SEASON_HISTORY = {
  "2025": [
    { date: "2025-06-26", label: "Thu, Jun 26", opponent: "St. Paul Blueshirts", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "W 16–14", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
    { date: "2025-06-28", label: "Sat, Jun 28", opponent: "Omaha Rebels", vs: "vs", location: "Veteran's Memorial Community Center", time: "5:00 PM", home: true, result: "W 17–14", oppLogo: "assets/img/opponents/omaha-rebels.png" },
    { date: "2025-06-29", label: "Sun, Jun 29", opponent: "Omaha Rebels", vs: "vs", location: "Veteran's Memorial Community Center", time: "12:00 PM", home: true, result: "W 23–11", oppLogo: "assets/img/opponents/omaha-rebels.png" },
    { date: "2025-07-15", label: "Tue, Jul 15", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "W 12–9", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2025-07-26", label: "Sat, Jul 26", opponent: "Minneapolis Wheatkings", vs: "@", location: "Northeast Ice Arena", time: "7:00 PM", home: false, result: "L 10–17", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2025-07-29", label: "Tue, Jul 29", opponent: "St. Paul Blueshirts", vs: "@", location: "Ken Yackel-West Side Arena", time: "7:00 PM", home: false, result: "W 12–11", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
    { date: "2025-08-02", label: "Sat, Aug 2", opponent: "Minneapolis Wheatkings", vs: "@", location: "Northeast Ice Arena", time: "7:00 PM", home: false, result: "L 12–14", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" }
  ],
  "2024": [
    { date: "2024-06-15", label: "Sat, Jun 15", opponent: "Iowa Dogfish", vs: "vs", location: "Veteran's Memorial Community Center", time: "12:00 PM", home: true, result: "W 17–12", oppLogo: null },
    { date: "2024-06-15", label: "Sat, Jun 15", opponent: "Iowa Dogfish", vs: "vs", location: "Veteran's Memorial Community Center", time: "3:30 PM", home: true, result: "W 17–5", oppLogo: null },
    { date: "2024-06-22", label: "Sat, Jun 22", opponent: "Omaha Rebels", vs: "@", location: "Off the Wall", time: "1:00 PM", home: false, result: "W 18–11", oppLogo: "assets/img/opponents/omaha-rebels.png" },
    { date: "2024-06-22", label: "Sat, Jun 22", opponent: "Omaha Rebels", vs: "@", location: "Off the Wall", time: "7:00 PM", home: false, result: "L 10–11", oppLogo: "assets/img/opponents/omaha-rebels.png" },
    { date: "2024-07-01", label: "Mon, Jul 1", opponent: "Minneapolis Wheatkings", vs: "@", location: "Northeast Ice Arena", time: "7:00 PM", home: false, result: "L 15–17", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2024-07-23", label: "Tue, Jul 23", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "L 5–13", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2024-07-25", label: "Thu, Jul 25", opponent: "St. Paul Blueshirts", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "W 22–14", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
    { date: "2024-07-31", label: "Wed, Jul 31", opponent: "St. Paul Blueshirts", vs: "@", location: "Northeast Ice Arena", time: "7:00 PM", home: false, result: "L 15–19", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
    { date: "2024-08-02", label: "Fri, Aug 2", opponent: "St. Paul Blueshirts", vs: "vs", location: "Veteran's Memorial Community Center", time: "6:30 PM", home: true, result: "L 21–22", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" }
  ],
  "2023": [
    { date: "2023-07-10", label: "Mon, Jul 10", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:15 PM", home: true, result: "L 16–19", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2023-07-13", label: "Thu, Jul 13", opponent: "St. Paul Blueshirts", vs: "@", location: "Northeast Ice Arena", time: "7:00 PM", home: false, result: "W 18–8", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
    { date: "2023-07-17", label: "Mon, Jul 17", opponent: "St. Paul Blueshirts", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:15 PM", home: true, result: "W 14–9", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
    { date: "2023-07-20", label: "Thu, Jul 20", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "L 8–12", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2023-07-22", label: "Sat, Jul 22", opponent: "Minneapolis Wheatkings", vs: "@", location: "Northeast Ice Arena", time: "7:00 PM", home: false, result: "L 8–20", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2023-07-23", label: "Sun, Jul 23", opponent: "St. Paul Blueshirts", vs: "@", location: "Veteran's Memorial Community Center", time: "3:00 PM", home: false, result: "W 15–14", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
    { date: "2023-07-28", label: "Fri, Jul 28", opponent: "Minneapolis Wheatkings", vs: "@", location: "Northeast Ice Arena", time: "7:00 PM", home: false, result: "L 12–17", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2023-07-29", label: "Sat, Jul 29", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "L 7–17", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" }
  ],
  "2022": [
    { date: "2022-07-23", label: "Sat, Jul 23", opponent: "Minnesota Freeze", vs: "@", location: "Charles M. Schulz - Highland Arena", time: "7:00 PM", home: false, result: "W 14–13", oppLogo: "assets/img/opponents/minnesota-freeze.jpg" },
    { date: "2022-07-30", label: "Sat, Jul 30", opponent: "Minnesota Freeze", vs: "vs", location: "Veteran's Memorial Community Center", time: "1:00 PM", home: true, result: "L 9–15", oppLogo: "assets/img/opponents/minnesota-freeze.jpg" },
    { date: "2022-07-30", label: "Sat, Jul 30", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "L 13–15", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2022-08-12", label: "Fri, Aug 12", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "L 7–21", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2022-08-16", label: "Tue, Aug 16", opponent: "Minneapolis Wheatkings", vs: "@", location: "Northeast Ice Arena", time: "7:00 PM", home: false, result: "L 7–16", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
    { date: "2022-08-20", label: "Sat, Aug 20", opponent: "Minnesota Freeze", vs: "vs", location: "Veteran's Memorial Community Center", time: "7:00 PM", home: true, result: "W 13–11", oppLogo: "assets/img/opponents/minnesota-freeze.jpg" }
  ]
};

// Senior regular-season games. type: "game"
const SCHEDULE = [
  { date: "2026-07-07", label: "Tue, Jul 7", opponent: "St. Paul Blueshirts", vs: "vs", location: "Veterans Memorial Community Center (VMCC) · 8055 Barbara Ave, Inver Grove Heights, MN 55077", time: "7:00 PM", home: true, result: "W 35–8", oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
  { date: "2026-07-11", label: "Sat, Jul 11", opponent: "Omaha Rebels", vs: "@", location: "The IceBox · 1880 Transformation Dr, Lincoln, NE 68501", time: "5:00 PM", home: false, result: "W 23–8", oppLogo: "assets/img/opponents/omaha-rebels.png" },
  { date: "2026-07-12", label: "Sun, Jul 12", opponent: "Omaha Rebels", vs: "@", location: "The IceBox · 1880 Transformation Dr, Lincoln, NE 68501", time: "12:00 PM", home: false, result: "L 14–15", oppLogo: "assets/img/opponents/omaha-rebels.png" },
  { date: "2026-07-14", label: "Tue, Jul 14", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veterans Memorial Community Center (VMCC) · 8055 Barbara Ave, Inver Grove Heights, MN 55077", time: "7:00 PM", home: true, result: "W 15–11", oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
  { date: "2026-07-18", label: "Sat, Jul 18", opponent: "Minneapolis Wheatkings", vs: "@", location: "Veterans Memorial Community Center (VMCC) · 8055 Barbara Ave, Inver Grove Heights, MN 55077", time: "7:00 PM", home: false, result: null, oppLogo: "assets/img/opponents/mpls-wheatkings.jpg" },
  { date: "2026-07-28", label: "Tue, Jul 28", opponent: "St. Paul Blueshirts", vs: "vs", location: "Veterans Memorial Community Center (VMCC) · 8055 Barbara Ave, Inver Grove Heights, MN 55077", time: "7:00 PM", home: true, result: null, oppLogo: "assets/img/opponents/stpaul-blueshirts.jpg" },
  { date: "2026-07-31", label: "Jul 31 – Aug 2", opponent: "Regional Playoffs", vs: "", location: "Site TBD", time: "TBD", home: null, result: null, oppLogo: null },
  { date: "2026-08-21", label: "Aug 21 – 23", opponent: "Senior Nationals", vs: "", location: "Utica, New York", time: "TBD", home: null, result: null, oppLogo: null }
];

// Non-game club events (banquets, clinics, fundraisers, etc). Empty
// until real events are added — add entries like:
// { date: "2026-08-22", label: "Sat, Aug 22", title: "Team Fundraiser Night",
//   location: "...", time: "6:00 PM", desc: "..." }
const EVENTS = [];

// Isotopes Juniors — a youth box lacrosse league the Isotopes organize
// and run at VMCC (not a traveling team), so this is an event calendar
// rather than a team-vs-opponent schedule.
const JUNIORS_SCHEDULE = [
  { date: "2026-07-16", label: "Thu, Jul 16", title: "Juniors Tryouts", type: "Tryouts", time: "6:00 – 8:00 PM", location: "Veterans Memorial Community Center (VMCC)" },
  { date: "2026-07-23", label: "Thu, Jul 23", title: "Juniors Game 1", type: "Game", time: "6:00 – 8:00 PM", location: "Veterans Memorial Community Center (VMCC)" },
  { date: "2026-07-24", label: "Jul 24 – 26", title: "Juniors Tournament — Vermont", type: "Tournament", time: "TBD", location: "Vermont (away trip)" },
  { date: "2026-07-30", label: "Thu, Jul 30", title: "Juniors Game 2", type: "Game", time: "7:00 – 9:00 PM", location: "Veterans Memorial Community Center (VMCC)" },
  { date: "2026-08-06", label: "Thu, Aug 6", title: "Juniors Game 3", type: "Game", time: "7:00 – 9:00 PM", location: "Veterans Memorial Community Center (VMCC)" },
  { date: "2026-08-13", label: "Thu, Aug 13", title: "Juniors Championship", type: "Championship", time: "7:00 – 9:00 PM", location: "Veterans Memorial Community Center (VMCC)" }
];

const JUNIORS_LOCATIONS = [
  { name: "Veterans Memorial Community Center", tag: "Home of the League", address: "8055 Barbara Ave, Inver Grove Heights, MN 55077", note: "Every Juniors tryout, game, and the championship are hosted here." },
  { name: "Vermont — Away Tournament", tag: "Jul 24 – 26", address: "Location TBD", note: "One away trip on the calendar this season — a multi-day tournament in Vermont." }
];

// Photo gallery. category: "senior" | "juniors" | "events"
const GALLERY = [
  { src: "assets/img/team-huddle.jpg", caption: "Isotopes huddle up before the opening whistle", category: "senior" },
  { src: "assets/img/action-04.jpg", caption: "Isotopes celebrate after a goal", category: "senior" },
  { src: "assets/img/action-05.jpg", caption: "Isotopes offense pushes the ball vs. St. Paul Blueshirts", category: "senior" },
  { src: "assets/img/action-06.jpg", caption: "Isotopes attacker crashes the crease vs. St. Paul Blueshirts", category: "senior" }
];
