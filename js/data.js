/*
  ISOTOPES LACROSSE — SITE DATA
  ------------------------------------------------------------
  Edit the arrays below to update the site. No HTML editing needed
  for roster, schedule, events, juniors info, or gallery photos.

  - ROSTER: add/remove players. `photo` can point to a real headshot
    in /assets/img/roster/ — leave null to show the jersey-number tile.
  - SCHEDULE: Senior A game list.
  - EVENTS: non-game team events (banquets, clinics, fundraisers, etc).
    Shown together with SCHEDULE on schedule.html.
  - JUNIORS_SCHEDULE / JUNIORS_LOCATIONS: juniors.html content.
  - GALLERY: photo gallery. `category` = "senior" | "juniors" | "events".
*/

const ROSTER = [
  {
    id: 1,
    number: 4,
    name: "Jake Reimer",
    position: "Attack",
    hometown: "Inver Grove Heights, MN",
    height: "5'11\"",
    shoots: "Right",
    experience: "6 seasons",
    photo: "assets/img/action-01.png",
    bio: "Jake has been a fixture on the Isotopes' front line since the club's second season. A crafty finisher with a quick release, he reads the floor a step ahead of most defenders and does his best work off the pick. Off the floor, he helps run the club's youth clinics.",
    stats: { games: 14, goals: 22, assists: 11, points: 33, penMin: 12 }
  },
  {
    id: 2,
    number: 64,
    name: "Marcus Odell",
    position: "Midfield",
    hometown: "St. Paul, MN",
    height: "6'1\"",
    shoots: "Left",
    experience: "4 seasons",
    photo: "assets/img/action-03.png",
    bio: "A tone-setting transition midfielder who thrives in the open floor. Marcus logs heavy minutes and brings the physicality the Isotopes are known for, anchoring both special teams units.",
    stats: { games: 14, goals: 9, assists: 14, points: 23, penMin: 24 }
  },
  {
    id: 3,
    number: 39,
    name: "Devon Whitcomb",
    position: "Midfield",
    hometown: "Woodbury, MN",
    height: "5'10\"",
    shoots: "Right",
    experience: "3 seasons",
    photo: null,
    bio: "Devon brings relentless motor and faceoff-wing awareness to the Isotopes' midfield rotation. Known for his work in transition, he's become one of the league's more dependable two-way players.",
    stats: { games: 13, goals: 6, assists: 8, points: 14, penMin: 10 }
  },
  {
    id: 4,
    number: 8,
    name: "Trevor Nash",
    position: "Defense",
    hometown: "Eagan, MN",
    height: "6'3\"",
    shoots: "Right",
    experience: "7 seasons",
    photo: null,
    bio: "The Isotopes' longest-tenured defender and a two-time club captain. Trevor's positioning and stick checks set the tone defensively, and he mentors every new face that comes through tryouts.",
    stats: { games: 14, goals: 1, assists: 5, points: 6, penMin: 28 }
  },
  {
    id: 5,
    number: 22,
    name: "Riley Voss",
    position: "Defense",
    hometown: "Burnsville, MN",
    height: "6'0\"",
    shoots: "Left",
    experience: "2 seasons",
    photo: null,
    bio: "A physical, close defender who took over a starting spot as a rookie. Riley's footwork and film study have made him one of the most improved players on the roster.",
    stats: { games: 12, goals: 0, assists: 3, points: 3, penMin: 20 }
  },
  {
    id: 6,
    number: 1,
    name: "Sam Okafor",
    position: "Goalie",
    hometown: "Minneapolis, MN",
    height: "5'11\"",
    shoots: "Right",
    experience: "5 seasons",
    photo: null,
    bio: "Sam anchors the Isotopes' crease with quick hands and calm decision-making under pressure. A former field lacrosse goalie, he made the full transition to box in 2022 and hasn't looked back.",
    stats: { games: 14, goals: 0, assists: 1, points: 1, penMin: 4 }
  },
  {
    id: 7,
    number: 17,
    name: "Colton Baird",
    position: "Attack",
    hometown: "Rosemount, MN",
    height: "5'9\"",
    shoots: "Left",
    experience: "1 season",
    photo: null,
    bio: "The newest addition to the offensive unit, Colton earned his spot at open tryouts this spring. Explosive first step and a knack for finding soft spots in zone coverage.",
    stats: { games: 10, goals: 8, assists: 4, points: 12, penMin: 6 }
  },
  {
    id: 8,
    number: 91,
    name: "Ben Kowalski",
    position: "Midfield",
    hometown: "Woodbury, MN",
    height: "6'2\"",
    shoots: "Right",
    experience: "5 seasons",
    photo: null,
    bio: "Ben's size and reach make him a matchup problem at both ends of the floor. He's the club's active leader in loose-ball recoveries over the last three seasons.",
    stats: { games: 13, goals: 5, assists: 7, points: 12, penMin: 16 }
  },
  {
    id: 9,
    number: 12,
    name: "Adam Levesque",
    position: "Defense",
    hometown: "Inver Grove Heights, MN",
    height: "6'0\"",
    shoots: "Right",
    experience: "3 seasons",
    photo: null,
    bio: "A hometown product who grew up through the Isotopes Juniors program before earning a Senior A roster spot. Adam's stick discipline and communication make him a coach favorite.",
    stats: { games: 14, goals: 0, assists: 2, points: 2, penMin: 14 }
  },
  {
    id: 10,
    number: 6,
    name: "Wyatt Sorenson",
    position: "Attack",
    hometown: "Apple Valley, MN",
    height: "5'10\"",
    shoots: "Right",
    experience: "4 seasons",
    photo: null,
    bio: "Wyatt's off-ball movement creates space for the rest of the offense, and his shot selection has steadily improved every season. A high-IQ player coaches trust in late-game situations.",
    stats: { games: 14, goals: 15, assists: 9, points: 24, penMin: 8 }
  },
  {
    id: 11,
    number: 44,
    name: "Isaac Ferro",
    position: "Midfield",
    hometown: "St. Paul, MN",
    height: "5'11\"",
    shoots: "Left",
    experience: "2 seasons",
    photo: null,
    bio: "A high-motor transition player who has carved out a role on the penalty-kill unit. Isaac's speed in the open floor consistently creates odd-man opportunities.",
    stats: { games: 11, goals: 4, assists: 6, points: 10, penMin: 12 }
  },
  {
    id: 12,
    number: 3,
    name: "Cole Ashworth",
    position: "Defense",
    hometown: "Burnsville, MN",
    height: "6'4\"",
    shoots: "Right",
    experience: "6 seasons",
    photo: null,
    bio: "The biggest presence on the Isotopes' back end, Cole clears the crease and wins the physical battles that decide close games. Also serves as an assistant coach for the Juniors program.",
    stats: { games: 14, goals: 1, assists: 4, points: 5, penMin: 30 }
  }
];

// Senior A regular-season games. type: "game"
const SCHEDULE = [
  { date: "2026-05-16", label: "Sat, May 16", opponent: "Minneapolis Storm", vs: "vs", location: "Veterans Memorial CC · Inver Grove Heights", time: "7:00 PM", home: true, result: "W 11–8" },
  { date: "2026-05-23", label: "Sat, May 23", opponent: "St. Paul Razors", vs: "@", location: "East Side Arena · St. Paul", time: "6:30 PM", home: false, result: "L 7–9" },
  { date: "2026-05-30", label: "Sat, May 30", opponent: "Burnsville Thunder", vs: "vs", location: "Veterans Memorial CC · Inver Grove Heights", time: "7:00 PM", home: true, result: "W 13–10" },
  { date: "2026-06-06", label: "Sat, Jun 6", opponent: "Eagan Eagles", vs: "@", location: "Eagan Civic Arena · Eagan", time: "8:00 PM", home: false, result: "W 10–9" },
  { date: "2026-06-20", label: "Sat, Jun 20", opponent: "Woodbury Wolves", vs: "vs", location: "Veterans Memorial CC · Inver Grove Heights", time: "7:00 PM", home: true, result: "L 8–12" },
  { date: "2026-06-27", label: "Sat, Jun 27", opponent: "Minneapolis Storm", vs: "@", location: "North Side Arena · Minneapolis", time: "6:30 PM", home: false, result: "W 14–6" },
  { date: "2026-07-11", label: "Sat, Jul 11", opponent: "St. Paul Razors", vs: "vs", location: "Veterans Memorial CC · Inver Grove Heights", time: "7:00 PM", home: true, result: "W 12–10" },
  { date: "2026-07-25", label: "Sat, Jul 25", opponent: "Burnsville Thunder", vs: "@", location: "Burnsville Ice Center · Burnsville", time: "8:00 PM", home: false, result: null },
  { date: "2026-08-08", label: "Sat, Aug 8", opponent: "Eagan Eagles", vs: "vs", location: "Veterans Memorial CC · Inver Grove Heights", time: "7:00 PM", home: true, result: null },
  { date: "2026-08-15", label: "Sat, Aug 15", opponent: "Woodbury Wolves", vs: "@", location: "Woodbury Community Center · Woodbury", time: "6:30 PM", home: false, result: null },
  { date: "2026-08-29", label: "Sat, Aug 29", opponent: "NABLL Playoffs · Round 1", vs: "TBD", location: "Higher seed hosts · Site TBD", time: "TBD", home: null, result: null }
];

// Non-game club events. type: "event"
const EVENTS = [
  { date: "2026-06-13", label: "Sat, Jun 13", title: "Isotopes Youth Clinic", location: "Veterans Memorial CC · Inver Grove Heights", time: "10:00 AM", desc: "Free stick-skills clinic for the Juniors program, run by the Senior A roster." },
  { date: "2026-07-18", label: "Sat, Jul 18", title: "Alumni Game & Cookout", location: "Veterans Memorial CC · Inver Grove Heights", time: "5:00 PM", desc: "Current roster faces off against Isotopes alumni, followed by a cookout for players and families." },
  { date: "2026-08-22", label: "Sat, Aug 22", title: "Team Fundraiser Night", location: "Inver Grove Tap House", time: "6:00 PM", desc: "Raffle and silent auction supporting the Isotopes' travel and equipment fund." },
  { date: "2026-09-12", label: "Sat, Sep 12", title: "End of Season Banquet", location: "Veterans Memorial CC · Inver Grove Heights", time: "6:30 PM", desc: "Awards, highlight reel, and a season send-off for players, coaches, and families." }
];

// Isotopes Juniors league schedule
const JUNIORS_SCHEDULE = [
  { date: "2026-05-17", label: "Sun, May 17", opponent: "Rosemount Youth Lacrosse", division: "14U", location: "Veterans Memorial CC · Inver Grove Heights", time: "1:00 PM", home: true },
  { date: "2026-05-17", label: "Sun, May 17", opponent: "Eagan Juniors", division: "16U", location: "Veterans Memorial CC · Inver Grove Heights", time: "2:30 PM", home: true },
  { date: "2026-05-31", label: "Sun, May 31", opponent: "Burnsville Youth Box", division: "14U", location: "Burnsville Ice Center · Burnsville", time: "12:00 PM", home: false },
  { date: "2026-06-14", label: "Sun, Jun 14", opponent: "Woodbury Wolves Juniors", division: "16U", location: "Woodbury Community Center · Woodbury", time: "1:30 PM", home: false },
  { date: "2026-06-28", label: "Sun, Jun 28", opponent: "St. Paul Razors Juniors", division: "14U", location: "Veterans Memorial CC · Inver Grove Heights", time: "1:00 PM", home: true },
  { date: "2026-07-19", label: "Sun, Jul 19", opponent: "Eagan Juniors", division: "16U", location: "Eagan Civic Arena · Eagan", time: "2:00 PM", home: false },
  { date: "2026-08-02", label: "Sun, Aug 2", opponent: "Rosemount Youth Lacrosse", division: "14U", location: "Veterans Memorial CC · Inver Grove Heights", time: "1:00 PM", home: true },
  { date: "2026-08-16", label: "Sun, Aug 16", opponent: "Regional Jamboree", division: "14U / 16U", location: "Elm Creek Fieldhouse · Maple Grove", time: "9:00 AM", home: false }
];

const JUNIORS_LOCATIONS = [
  { name: "Veterans Memorial Community Center", tag: "Primary Home Venue", address: "8055 Barbara Ave, Inver Grove Heights, MN 55076", note: "Home box for both 14U and 16U divisions, plus all practices." },
  { name: "Simley Middle School Fieldhouse", tag: "Practice Facility", address: "2920 80th St E, Inver Grove Heights, MN 55076", note: "Weeknight practice space during peak spring scheduling." },
  { name: "Various League Venues", tag: "Away Games", address: "Rotates across the metro youth box league", note: "Away opponents host at their home facility — see schedule for each week's location." }
];

// Photo gallery. category: "senior" | "juniors" | "events"
const GALLERY = [
  { src: "assets/img/action-01.png", caption: "Senior A in transition vs. Burnsville", category: "senior" },
  { src: "assets/img/action-02.png", caption: "Isotopes offense working the crease", category: "senior" },
  { src: "assets/img/action-03.png", caption: "Isotopes celebrate a home win", category: "senior" }
];
