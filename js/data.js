/*
  ISOTOPES LACROSSE — SITE DATA
  ------------------------------------------------------------
  Edit the arrays below to update the site. No HTML editing needed
  for roster, schedule, events, juniors info, or gallery photos.

  - ROSTER: add/remove players. `photo` can point to a real headshot
    in /assets/img/roster/ — leave null to show the jersey-number tile.
  - SCHEDULE: Senior A game list. `oppLogo` can point to a team logo in
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
  { date: "2026-07-07", label: "Tue, Jul 7", opponent: "St. Paul Blueshirts", vs: "vs", location: "Veterans Memorial Community Center (VMCC) · 8055 Barbara Ave, Inver Grove Heights, MN 55077", time: "TBD", home: true, result: "W 35–8", oppLogo: null },
  { date: "2026-07-11", label: "Sat, Jul 11", opponent: "Omaha Rebels", vs: "@", location: "The IceBox · 1880 Transformation Dr, Lincoln, NE 68501", time: "5:00 PM", home: false, result: "W 23–8", oppLogo: null },
  { date: "2026-07-12", label: "Sun, Jul 12", opponent: "Omaha Rebels", vs: "@", location: "The IceBox · 1880 Transformation Dr, Lincoln, NE 68501", time: "12:00 PM", home: false, result: "L 14–15", oppLogo: null },
  { date: "2026-07-14", label: "Tue, Jul 14", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veterans Memorial Community Center (VMCC) · 8055 Barbara Ave, Inver Grove Heights, MN 55077", time: "7:00 PM", home: true, result: "W 15–11", oppLogo: null },
  { date: "2026-07-18", label: "Sat, Jul 18", opponent: "Minneapolis Wheatkings", vs: "vs", location: "Veterans Memorial Community Center (VMCC) · 8055 Barbara Ave, Inver Grove Heights, MN 55077", time: "7:00 PM", home: true, result: null, oppLogo: null },
  { date: "2026-07-28", label: "Tue, Jul 28", opponent: "St. Paul Blueshirts", vs: "vs", location: "Veterans Memorial Community Center (VMCC) · 8055 Barbara Ave, Inver Grove Heights, MN 55077", time: "7:00 PM", home: true, result: null, oppLogo: null },
  { date: "2026-07-31", label: "Jul 31 – Aug 2", opponent: "Regional Playoffs", vs: "", location: "Site TBD", time: "TBD", home: null, result: null, oppLogo: null },
  { date: "2026-08-21", label: "Aug 21 – 23", opponent: "Senior A Nationals", vs: "", location: "Utica, New York", time: "TBD", home: null, result: null, oppLogo: null }
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
  { src: "assets/img/action-01.png", caption: "Senior A in transition vs. Burnsville", category: "senior" },
  { src: "assets/img/action-02.png", caption: "Isotopes offense working the crease", category: "senior" },
  { src: "assets/img/action-03.png", caption: "Isotopes celebrate a home win", category: "senior" }
];
