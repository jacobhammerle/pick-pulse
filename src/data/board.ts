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
    player: 'Jalen Carter',
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
    player: 'Marcus Webb',
    team: 'ATL',
    opponent: 'vs MIA',
    league: 'NBA',
    position: 'C',
    stat: 'Rebounds',
    line: 11.5,
    gameTime: 'Tonight 7:30 PM',
    emoji: '🏀',
  },
  {
    id: 'p3',
    player: 'Devin Rousseau',
    team: 'BOS',
    opponent: '@ NYK',
    league: 'NBA',
    position: 'SG',
    stat: '3-PT Made',
    line: 3.5,
    gameTime: 'Tonight 8:00 PM',
    emoji: '🏀',
  },
  {
    id: 'p4',
    player: 'Tyree Holloway',
    team: 'DAL',
    opponent: 'vs PHI',
    league: 'NFL',
    position: 'QB',
    stat: 'Pass Yards',
    line: 265.5,
    gameTime: 'Sun 1:00 PM',
    emoji: '🏈',
  },
  {
    id: 'p5',
    player: 'Andre Bishop',
    team: 'DAL',
    opponent: 'vs PHI',
    league: 'NFL',
    position: 'WR',
    stat: 'Receiving Yards',
    line: 72.5,
    gameTime: 'Sun 1:00 PM',
    emoji: '🏈',
  },
  {
    id: 'p6',
    player: 'Luis Herrera',
    team: 'ATL',
    opponent: '@ SD',
    league: 'MLB',
    position: 'SS',
    stat: 'Total Bases',
    line: 1.5,
    gameTime: 'Tomorrow 6:45 PM',
    emoji: '⚾',
  },
  {
    id: 'p7',
    player: 'Kenji Sato',
    team: 'SD',
    opponent: 'vs ATL',
    league: 'MLB',
    position: 'SP',
    stat: 'Strikeouts',
    line: 6.5,
    gameTime: 'Tomorrow 6:45 PM',
    emoji: '⚾',
  },
  {
    id: 'p8',
    player: 'Cam Whitfield',
    team: 'BOS',
    opponent: '@ NYK',
    league: 'NBA',
    position: 'PF',
    stat: 'Pts + Rebs + Asts',
    line: 34.5,
    gameTime: 'Tonight 8:00 PM',
    emoji: '🏀',
  },
];
