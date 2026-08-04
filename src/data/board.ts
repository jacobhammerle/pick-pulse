export type PropLine = {
  id: string;
  player: string;
  team: string;
  opponent: string;
  league: 'NBA' | 'NFL' | 'MLB';
  position: string;
  stat: string;
  line: number;
  gameTime: string;
  emoji: string;
};

export const BOARD: PropLine[] = [
  {
    id: 'p1',
    player: 'Trae Young',
    team: 'ATL',
    opponent: 'vs MIA',
    league: 'NBA',
    position: 'PG',
    stat: 'Points',
    line: 27.5,
    gameTime: 'Tonight 7:30 PM',
    emoji: '🏀',
  },
  {
    id: 'p2',
    player: 'Jalen Johnson',
    team: 'ATL',
    opponent: 'vs MIA',
    league: 'NBA',
    position: 'PF',
    stat: 'Rebounds',
    line: 11.5,
    gameTime: 'Tonight 7:30 PM',
    emoji: '🏀',
  },
  {
    id: 'p3',
    player: 'Joe Burrow',
    team: 'CIN',
    opponent: 'vs BAL',
    league: 'NFL',
    position: 'QB',
    stat: 'Pass Yards',
    line: 265.5,
    gameTime: 'Sun 1:00 PM',
    emoji: '🏈',
  },
  {
    id: 'p4',
    player: 'Bijan Robinson',
    team: 'ATL',
    opponent: 'vs NO',
    league: 'NFL',
    position: 'RB',
    stat: 'Rush Yards',
    line: 88.5,
    gameTime: 'Sun 1:00 PM',
    emoji: '🏈',
  },
  {
    id: 'p5',
    player: 'Drake London',
    team: 'ATL',
    opponent: 'vs NO',
    league: 'NFL',
    position: 'WR',
    stat: 'Receiving Yards',
    line: 72.5,
    gameTime: 'Sun 1:00 PM',
    emoji: '🏈',
  },
  {
    id: 'p6',
    player: 'Ronald Acuña Jr.',
    team: 'ATL',
    opponent: '@ SD',
    league: 'MLB',
    position: 'RF',
    stat: 'Total Bases',
    line: 1.5,
    gameTime: 'Tomorrow 6:45 PM',
    emoji: '⚾',
  },
  {
    id: 'p7',
    player: 'Chris Sale',
    team: 'ATL',
    opponent: '@ SD',
    league: 'MLB',
    position: 'SP',
    stat: 'Strikeouts',
    line: 6.5,
    gameTime: 'Tomorrow 6:45 PM',
    emoji: '⚾',
  },
  {
    id: 'p8',
    player: 'Matt Olson',
    team: 'ATL',
    opponent: '@ SD',
    league: 'MLB',
    position: '1B',
    stat: 'Hits + Runs + RBIs',
    line: 2.5,
    gameTime: 'Tomorrow 6:45 PM',
    emoji: '⚾',
  },
];
