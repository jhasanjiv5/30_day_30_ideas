import { createRng, cosineSimilarity, normalize } from './math';
import { CatalogItem, DatasetMode, UserProfile } from './types';

// 12D Latent Basis:
// 0: sci-fi / speculative tech
// 1: noir / mystery / shadow
// 2: drama / character study
// 3: thriller / suspense / tension
// 4: comedy / satire / light
// 5: documentary / realism
// 6: animation / visual stylization
// 7: slow-burn / contemplative
// 8: nonlinear / cerebral
// 9: mainstream / blockbuster scale
// 10: classic / retrospective
// 11: experimental / avant-garde

interface RawMovieSpec {
  id: string;
  title: string;
  year: number;
  category: string;
  tags: string[];
  vec: number[];
  popularity: number;
  historicalAvgSlot: number;
}

const RAW_MOVIES: RawMovieSpec[] = [
  // Sci-Fi / Cyberpunk / Speculative
  { id: 'm01', title: 'Blade Runner', year: 1982, category: 'Sci-Fi', tags: ['cyberpunk', 'neo-noir', 'artificial-intelligence', 'dystopian', 'rain-soaked', 'philosophical'], vec: [0.95, 0.85, 0.35, 0.45, 0.0, 0.0, 0.2, 0.75, 0.55, 0.55, 0.85, 0.45], popularity: 0.91, historicalAvgSlot: 1.8 },
  { id: 'm02', title: 'Arrival', year: 2016, category: 'Sci-Fi', tags: ['first-contact', 'linguistics', 'nonlinear', 'slow-burn', 'emotional', 'sci-fi'], vec: [0.92, 0.15, 0.72, 0.35, 0.0, 0.1, 0.1, 0.85, 0.92, 0.65, 0.15, 0.35], popularity: 0.89, historicalAvgSlot: 1.4 },
  { id: 'm03', title: 'Ex Machina', year: 2014, category: 'Sci-Fi', tags: ['artificial-intelligence', 'claustrophobic', 'turing-test', 'cerebral', 'sci-fi', 'minimalist'], vec: [0.94, 0.35, 0.42, 0.75, 0.0, 0.0, 0.1, 0.68, 0.82, 0.45, 0.12, 0.40], popularity: 0.86, historicalAvgSlot: 2.1 },
  { id: 'm04', title: 'Children of Men', year: 2006, category: 'Sci-Fi', tags: ['dystopian', 'long-take', 'bleak', 'sci-fi', 'thriller', 'world-building'], vec: [0.82, 0.30, 0.58, 0.85, 0.0, 0.35, 0.0, 0.35, 0.35, 0.62, 0.32, 0.30], popularity: 0.84, historicalAvgSlot: 2.8 },
  { id: 'm05', title: 'Blade Runner 2049', year: 2017, category: 'Sci-Fi', tags: ['cyberpunk', 'neo-noir', 'artificial-intelligence', 'slow-burn', 'cinematography', 'sci-fi'], vec: [0.96, 0.78, 0.48, 0.42, 0.0, 0.0, 0.25, 0.88, 0.62, 0.72, 0.18, 0.42], popularity: 0.88, historicalAvgSlot: 1.9 },
  { id: 'm06', title: 'Solaris', year: 1972, category: 'Sci-Fi', tags: ['space', 'philosophical', 'slow-burn', 'memory', 'experimental', 'sci-fi'], vec: [0.85, 0.15, 0.65, 0.1, 0.0, 0.0, 0.1, 0.98, 0.85, 0.12, 0.95, 0.92], popularity: 0.56, historicalAvgSlot: 7.4 },
  { id: 'm07', title: 'Annihilation', year: 2018, category: 'Sci-Fi', tags: ['cosmic-horror', 'biology', 'nonlinear', 'surreal', 'sci-fi', 'expedition'], vec: [0.90, 0.25, 0.38, 0.72, 0.0, 0.0, 0.22, 0.65, 0.84, 0.42, 0.10, 0.85], popularity: 0.78, historicalAvgSlot: 4.5 },
  { id: 'm08', title: 'Primer', year: 2004, category: 'Sci-Fi', tags: ['time-loop', 'low-budget', 'nonlinear', 'hard-sci-fi', 'puzzle', 'cerebral'], vec: [0.95, 0.10, 0.22, 0.45, 0.0, 0.15, 0.0, 0.48, 0.99, 0.08, 0.25, 0.88], popularity: 0.61, historicalAvgSlot: 6.8 },
  { id: 'm09', title: 'Her', year: 2013, category: 'Sci-Fi', tags: ['artificial-intelligence', 'loneliness', 'near-future', 'romance', 'melancholy', 'sci-fi'], vec: [0.76, 0.05, 0.88, 0.10, 0.22, 0.0, 0.1, 0.72, 0.45, 0.44, 0.12, 0.38], popularity: 0.83, historicalAvgSlot: 3.1 },
  { id: 'm10', title: 'Gattaca', year: 1997, category: 'Sci-Fi', tags: ['genetics', 'dystopian', 'retro-futurism', 'identity', 'sci-fi', 'sleek'], vec: [0.88, 0.42, 0.62, 0.58, 0.0, 0.0, 0.0, 0.55, 0.48, 0.48, 0.62, 0.25], popularity: 0.77, historicalAvgSlot: 4.2 },
  { id: 'm11', title: '2001: A Space Odyssey', year: 1968, category: 'Sci-Fi', tags: ['space-opera', 'artificial-intelligence', 'philosophical', 'slow-burn', 'practical-effects', 'sci-fi'], vec: [0.97, 0.05, 0.30, 0.25, 0.0, 0.1, 0.2, 0.98, 0.88, 0.75, 0.98, 0.95], popularity: 0.90, historicalAvgSlot: 2.2 },
  { id: 'm12', title: 'Ghost in the Shell', year: 1995, category: 'Sci-Fi', tags: ['cyberpunk', 'anime', 'artificial-intelligence', 'identity', 'neo-noir', 'sci-fi'], vec: [0.94, 0.68, 0.35, 0.58, 0.0, 0.0, 0.92, 0.62, 0.72, 0.38, 0.74, 0.60], popularity: 0.79, historicalAvgSlot: 4.8 },
  { id: 'm13', title: 'Moon', year: 2009, category: 'Sci-Fi', tags: ['isolation', 'lunar', 'clones', 'mystery', 'practical-effects', 'sci-fi'], vec: [0.92, 0.22, 0.58, 0.55, 0.05, 0.0, 0.0, 0.70, 0.65, 0.22, 0.24, 0.38], popularity: 0.74, historicalAvgSlot: 5.5 },
  { id: 'm14', title: 'Interstellar', year: 2014, category: 'Sci-Fi', tags: ['space', 'relativity', 'time-dilation', 'epic', 'emotional', 'sci-fi'], vec: [0.94, 0.05, 0.65, 0.62, 0.0, 0.05, 0.1, 0.48, 0.74, 0.98, 0.12, 0.22], popularity: 0.96, historicalAvgSlot: 1.1 },
  { id: 'm15', title: 'The Matrix', year: 1999, category: 'Sci-Fi', tags: ['cyberpunk', 'simulation', 'martial-arts', 'dystopian', 'sci-fi', 'philosophical'], vec: [0.92, 0.48, 0.20, 0.88, 0.0, 0.0, 0.1, 0.20, 0.65, 0.97, 0.68, 0.35], popularity: 0.97, historicalAvgSlot: 1.2 },
  { id: 'm16', title: 'Stalker', year: 1979, category: 'Sci-Fi', tags: ['zone', 'philosophical', 'slow-burn', 'post-apocalyptic', 'existential', 'sci-fi'], vec: [0.76, 0.25, 0.62, 0.20, 0.0, 0.1, 0.0, 0.99, 0.82, 0.08, 0.92, 0.96], popularity: 0.52, historicalAvgSlot: 8.6 },
  { id: 'm17', title: '12 Monkeys', year: 1995, category: 'Sci-Fi', tags: ['time-travel', 'dystopian', 'nonlinear', 'paranoia', 'sci-fi', 'plague'], vec: [0.85, 0.45, 0.38, 0.74, 0.10, 0.0, 0.05, 0.35, 0.85, 0.62, 0.65, 0.62], popularity: 0.81, historicalAvgSlot: 3.4 },
  { id: 'm18', title: 'Under the Skin', year: 2013, category: 'Sci-Fi', tags: ['alien', 'experimental', 'minimal-dialogue', 'eerie', 'sci-fi', 'hypnotic'], vec: [0.78, 0.40, 0.35, 0.42, 0.0, 0.2, 0.0, 0.92, 0.72, 0.12, 0.14, 0.96], popularity: 0.58, historicalAvgSlot: 7.9 },
  { id: 'm19', title: 'Akira', year: 1988, category: 'Sci-Fi', tags: ['cyberpunk', 'anime', 'tokyo', 'telekinesis', 'dystopian', 'sci-fi'], vec: [0.90, 0.45, 0.25, 0.75, 0.0, 0.0, 0.96, 0.25, 0.58, 0.55, 0.82, 0.68], popularity: 0.82, historicalAvgSlot: 3.9 },
  { id: 'm20', title: 'Dune: Part Two', year: 2024, category: 'Sci-Fi', tags: ['space-opera', 'desert', 'epic', 'prophecy', 'world-building', 'sci-fi'], vec: [0.95, 0.15, 0.52, 0.78, 0.0, 0.0, 0.15, 0.48, 0.42, 0.96, 0.05, 0.28], popularity: 0.95, historicalAvgSlot: 1.3 },
  { id: 'm21', title: 'Coherence', year: 2013, category: 'Sci-Fi', tags: ['multiverse', 'dinner-party', 'puzzle', 'low-budget', 'thriller', 'sci-fi'], vec: [0.86, 0.25, 0.32, 0.76, 0.0, 0.0, 0.0, 0.32, 0.92, 0.16, 0.12, 0.68], popularity: 0.66, historicalAvgSlot: 6.4 },
  { id: 'm22', title: 'Dark City', year: 1998, category: 'Sci-Fi', tags: ['neo-noir', 'memory', 'simulation', 'expressionist', 'sci-fi', 'mystery'], vec: [0.86, 0.88, 0.25, 0.68, 0.0, 0.0, 0.15, 0.42, 0.72, 0.35, 0.68, 0.52], popularity: 0.70, historicalAvgSlot: 5.8 },

  // Noir / Neo-Noir / Mystery
  { id: 'm23', title: 'Chinatown', year: 1974, category: 'Noir', tags: ['detective', 'corruption', 'los-angeles', 'neo-noir', 'cynical', 'mystery'], vec: [0.0, 0.98, 0.74, 0.62, 0.0, 0.05, 0.0, 0.68, 0.48, 0.64, 0.96, 0.18], popularity: 0.87, historicalAvgSlot: 2.0 },
  { id: 'm24', title: 'Mulholland Drive', year: 2001, category: 'Noir', tags: ['surreal', 'nonlinear', 'los-angeles', 'dreamlike', 'neo-noir', 'mystery'], vec: [0.10, 0.86, 0.55, 0.52, 0.05, 0.0, 0.0, 0.78, 0.96, 0.25, 0.42, 0.94], popularity: 0.79, historicalAvgSlot: 4.1 },
  { id: 'm25', title: 'The Conversation', year: 1974, category: 'Noir', tags: ['surveillance', 'paranoia', 'sound-design', 'slow-burn', 'neo-noir', 'character-study'], vec: [0.15, 0.84, 0.78, 0.66, 0.0, 0.12, 0.0, 0.85, 0.55, 0.28, 0.94, 0.42], popularity: 0.71, historicalAvgSlot: 5.2 },
  { id: 'm26', title: 'L.A. Confidential', year: 1997, category: 'Noir', tags: ['detective', '1950s', 'corruption', 'neo-noir', 'ensemble', 'crime'], vec: [0.0, 0.94, 0.58, 0.78, 0.0, 0.0, 0.0, 0.35, 0.42, 0.78, 0.65, 0.10], popularity: 0.86, historicalAvgSlot: 2.3 },
  { id: 'm27', title: 'Double Indemnity', year: 1944, category: 'Noir', tags: ['femme-fatale', 'insurance-fraud', 'black-and-white', 'classic-noir', 'voiceover'], vec: [0.0, 0.99, 0.52, 0.65, 0.0, 0.0, 0.0, 0.45, 0.25, 0.45, 0.99, 0.15], popularity: 0.76, historicalAvgSlot: 4.9 },
  { id: 'm28', title: 'The Third Man', year: 1949, category: 'Noir', tags: ['vienna', 'post-war', 'black-and-white', 'classic-noir', 'zither', 'shadow'], vec: [0.0, 0.97, 0.55, 0.68, 0.0, 0.05, 0.0, 0.52, 0.30, 0.42, 0.98, 0.25], popularity: 0.75, historicalAvgSlot: 5.1 },
  { id: 'm29', title: 'Memories of Murder', year: 2003, category: 'Noir', tags: ['procedural', 'rain-soaked', 'korean-cinema', 'unsolved', 'bleak', 'mystery'], vec: [0.0, 0.85, 0.76, 0.82, 0.12, 0.15, 0.0, 0.64, 0.38, 0.46, 0.34, 0.30], popularity: 0.82, historicalAvgSlot: 3.3 },
  { id: 'm30', title: 'Blood Simple', year: 1984, category: 'Noir', tags: ['texas', 'neo-noir', 'double-cross', 'coen-brothers', 'tension', 'crime'], vec: [0.0, 0.92, 0.45, 0.84, 0.15, 0.0, 0.0, 0.46, 0.28, 0.32, 0.78, 0.28], popularity: 0.72, historicalAvgSlot: 5.9 },
  { id: 'm31', title: 'Memento', year: 2000, category: 'Noir', tags: ['amnesia', 'nonlinear', 'neo-noir', 'reverse-chronology', 'puzzle', 'thriller'], vec: [0.08, 0.82, 0.42, 0.86, 0.0, 0.0, 0.0, 0.35, 0.98, 0.72, 0.45, 0.58], popularity: 0.91, historicalAvgSlot: 1.7 },
  { id: 'm32', title: 'Brick', year: 2005, category: 'Noir', tags: ['high-school', 'hardboiled', 'neo-noir', 'slang', 'indie', 'detective'], vec: [0.0, 0.90, 0.48, 0.62, 0.08, 0.0, 0.0, 0.42, 0.45, 0.22, 0.32, 0.54], popularity: 0.68, historicalAvgSlot: 6.2 },
  { id: 'm33', title: 'Le Samourai', year: 1967, category: 'Noir', tags: ['hitman', 'french-new-wave', 'minimalist', 'cool', 'trenchcoat', 'classic-noir'], vec: [0.0, 0.94, 0.52, 0.58, 0.0, 0.0, 0.0, 0.84, 0.22, 0.24, 0.96, 0.42], popularity: 0.69, historicalAvgSlot: 6.1 },
  { id: 'm34', title: 'Zodiac', year: 2007, category: 'Noir', tags: ['procedural', 'obsession', 'san-francisco', '1970s', 'investigative', 'slow-burn'], vec: [0.0, 0.80, 0.68, 0.82, 0.0, 0.35, 0.0, 0.78, 0.32, 0.64, 0.28, 0.15], popularity: 0.85, historicalAvgSlot: 2.6 },

  // Drama / Indie / Character Study
  { id: 'm35', title: 'Moonlight', year: 2016, category: 'Drama', tags: ['coming-of-age', 'triptych', 'miami', 'intimate', 'indie', 'poetic'], vec: [0.0, 0.10, 0.98, 0.15, 0.0, 0.10, 0.0, 0.82, 0.42, 0.35, 0.12, 0.55], popularity: 0.84, historicalAvgSlot: 2.9 },
  { id: 'm36', title: 'There Will Be Blood', year: 2007, category: 'Drama', tags: ['oil', 'ambition', 'character-study', 'score', 'period-piece', 'epic'], vec: [0.0, 0.28, 0.96, 0.45, 0.0, 0.12, 0.0, 0.78, 0.22, 0.62, 0.35, 0.38], popularity: 0.88, historicalAvgSlot: 2.4 },
  { id: 'm37', title: 'In the Mood for Love', year: 2000, category: 'Drama', tags: ['hong-kong', '1960s', 'longing', 'slow-burn', 'color-palette', 'romance'], vec: [0.0, 0.22, 0.95, 0.05, 0.0, 0.0, 0.12, 0.92, 0.32, 0.24, 0.52, 0.56], popularity: 0.78, historicalAvgSlot: 4.4 },
  { id: 'm38', title: 'Aftersun', year: 2022, category: 'Drama', tags: ['memory', 'camcorder', 'father-daughter', 'indie', 'melancholy', 'minimalist'], vec: [0.0, 0.05, 0.96, 0.05, 0.05, 0.18, 0.0, 0.88, 0.52, 0.18, 0.05, 0.62], popularity: 0.73, historicalAvgSlot: 5.3 },
  { id: 'm39', title: 'Past Lives', year: 2023, category: 'Drama', tags: ['destiny', 'new-york', 'seoul', 'intimate', 'romance', 'indie'], vec: [0.0, 0.02, 0.94, 0.05, 0.10, 0.05, 0.0, 0.76, 0.25, 0.36, 0.05, 0.22], popularity: 0.79, historicalAvgSlot: 3.7 },
  { id: 'm40', title: 'Anatomy of a Fall', year: 2023, category: 'Drama', tags: ['courtroom', 'marriage', 'french-alps', 'ambiguity', 'dialogue', 'mystery'], vec: [0.0, 0.48, 0.92, 0.68, 0.0, 0.18, 0.0, 0.66, 0.42, 0.44, 0.05, 0.25], popularity: 0.81, historicalAvgSlot: 3.5 },
  { id: 'm41', title: 'Tar', year: 2022, category: 'Drama', tags: ['conductor', 'power', 'character-study', 'berlin', 'slow-burn', 'psychological'], vec: [0.0, 0.35, 0.94, 0.48, 0.08, 0.12, 0.0, 0.84, 0.45, 0.32, 0.08, 0.48], popularity: 0.74, historicalAvgSlot: 5.0 },
  { id: 'm42', title: 'Whiplash', year: 2014, category: 'Drama', tags: ['jazz', 'obsession', 'mentor', 'intense', 'music', 'tight-editing'], vec: [0.0, 0.12, 0.88, 0.84, 0.0, 0.05, 0.0, 0.18, 0.15, 0.76, 0.14, 0.18], popularity: 0.93, historicalAvgSlot: 1.5 },
  { id: 'm43', title: 'Manchester by the Sea', year: 2016, category: 'Drama', tags: ['grief', 'new-england', 'working-class', 'naturalistic', 'character-study'], vec: [0.0, 0.05, 0.97, 0.10, 0.12, 0.15, 0.0, 0.82, 0.24, 0.38, 0.10, 0.15], popularity: 0.80, historicalAvgSlot: 3.8 },
  { id: 'm44', title: 'Portrait of a Lady on Fire', year: 2019, category: 'Drama', tags: ['painting', '18th-century', 'brittany', 'romance', 'slow-burn', 'gaze'], vec: [0.0, 0.08, 0.96, 0.08, 0.0, 0.0, 0.08, 0.90, 0.22, 0.28, 0.12, 0.46], popularity: 0.77, historicalAvgSlot: 4.3 },
  { id: 'm45', title: 'The Shawshank Redemption', year: 1994, category: 'Drama', tags: ['prison', 'friendship', 'hope', 'narration', 'classic', 'redemption'], vec: [0.0, 0.22, 0.94, 0.42, 0.08, 0.0, 0.0, 0.45, 0.12, 0.96, 0.84, 0.05], popularity: 0.99, historicalAvgSlot: 1.0 },
  { id: 'm46', title: 'Paris, Texas', year: 1984, category: 'Drama', tags: ['road-movie', 'desert', 'memory', 'americana', 'slow-burn', 'guitar'], vec: [0.0, 0.15, 0.94, 0.08, 0.05, 0.12, 0.0, 0.92, 0.28, 0.18, 0.86, 0.52], popularity: 0.69, historicalAvgSlot: 6.3 },

  // Thriller / Suspense / Crime
  { id: 'm47', title: 'Parasite', year: 2019, category: 'Thriller', tags: ['class-satire', 'seoul', 'architecture', 'dark-comedy', 'twist', 'thriller'], vec: [0.0, 0.42, 0.74, 0.88, 0.45, 0.0, 0.0, 0.28, 0.45, 0.86, 0.08, 0.38], popularity: 0.95, historicalAvgSlot: 1.2 },
  { id: 'm48', title: 'No Country for Old Men', year: 2007, category: 'Thriller', tags: ['texas', 'cat-and-mouse', 'fatalism', 'western-noir', 'minimal-score'], vec: [0.0, 0.76, 0.58, 0.94, 0.05, 0.05, 0.0, 0.55, 0.24, 0.78, 0.28, 0.32], popularity: 0.92, historicalAvgSlot: 1.6 },
  { id: 'm49', title: 'Sicario', year: 2015, category: 'Thriller', tags: ['border', 'cartel', 'tension', 'cinematography', 'procedural', 'bleak'], vec: [0.0, 0.58, 0.42, 0.96, 0.0, 0.18, 0.0, 0.42, 0.18, 0.74, 0.12, 0.20], popularity: 0.87, historicalAvgSlot: 2.2 },
  { id: 'm50', title: 'Prisoners', year: 2013, category: 'Thriller', tags: ['kidnapping', 'pennsylvania', 'rain', 'moral-decay', 'detective', 'suspense'], vec: [0.0, 0.74, 0.66, 0.94, 0.0, 0.0, 0.0, 0.52, 0.24, 0.72, 0.12, 0.12], popularity: 0.88, historicalAvgSlot: 2.0 },
  { id: 'm51', title: 'Se7en', year: 1995, category: 'Thriller', tags: ['serial-killer', 'rain-soaked', 'neo-noir', 'detective', 'grim', 'twist'], vec: [0.0, 0.90, 0.45, 0.95, 0.0, 0.0, 0.0, 0.35, 0.28, 0.88, 0.68, 0.22], popularity: 0.94, historicalAvgSlot: 1.4 },
  { id: 'm52', title: 'Uncut Gems', year: 2019, category: 'Thriller', tags: ['new-york', 'gambling', 'anxiety', 'fast-paced', 'jewelry', 'synth-score'], vec: [0.0, 0.35, 0.58, 0.92, 0.22, 0.12, 0.0, 0.05, 0.22, 0.58, 0.08, 0.48], popularity: 0.81, historicalAvgSlot: 3.6 },
  { id: 'm53', title: 'Nightcrawler', year: 2014, category: 'Thriller', tags: ['los-angeles', 'media-satire', 'sociopath', 'nocturnal', 'neo-noir', 'ambition'], vec: [0.0, 0.78, 0.45, 0.88, 0.22, 0.10, 0.0, 0.28, 0.22, 0.60, 0.10, 0.32], popularity: 0.85, historicalAvgSlot: 2.7 },
  { id: 'm54', title: 'Heat', year: 1995, category: 'Thriller', tags: ['heist', 'los-angeles', 'cat-and-mouse', 'gunfight', 'neo-noir', 'ensemble'], vec: [0.0, 0.74, 0.58, 0.90, 0.0, 0.0, 0.0, 0.42, 0.15, 0.84, 0.68, 0.10], popularity: 0.89, historicalAvgSlot: 1.9 },
  { id: 'm55', title: 'Oldboy', year: 2003, category: 'Thriller', tags: ['revenge', 'korean-cinema', 'hallway-fight', 'twist', 'neo-noir', 'visceral'], vec: [0.0, 0.72, 0.45, 0.90, 0.05, 0.0, 0.0, 0.25, 0.62, 0.58, 0.36, 0.58], popularity: 0.84, historicalAvgSlot: 3.0 },
  { id: 'm56', title: 'Gone Girl', year: 2014, category: 'Thriller', tags: ['marriage', 'media', 'unreliable-narrator', 'twist', 'cold', 'mystery'], vec: [0.0, 0.65, 0.52, 0.89, 0.18, 0.0, 0.0, 0.32, 0.54, 0.84, 0.10, 0.18], popularity: 0.88, historicalAvgSlot: 2.1 },

  // Documentary / Nonfiction
  { id: 'm57', title: 'Free Solo', year: 2018, category: 'Documentary', tags: ['climbing', 'yosemite', 'obsession', 'heights', 'athletic', 'documentary'], vec: [0.0, 0.0, 0.45, 0.78, 0.0, 0.98, 0.0, 0.35, 0.08, 0.62, 0.05, 0.12], popularity: 0.78, historicalAvgSlot: 4.0 },
  { id: 'm58', title: 'Jiro Dreams of Sushi', year: 2011, category: 'Documentary', tags: ['craft', 'tokyo', 'culinary', 'perfectionism', 'slow-burn', 'documentary'], vec: [0.0, 0.0, 0.55, 0.05, 0.05, 0.98, 0.0, 0.76, 0.08, 0.38, 0.14, 0.15], popularity: 0.72, historicalAvgSlot: 5.4 },
  { id: 'm59', title: 'The Act of Killing', year: 2012, category: 'Documentary', tags: ['indonesia', 'history', 'surreal', 'memory', 'experimental', 'documentary'], vec: [0.0, 0.35, 0.62, 0.35, 0.0, 0.96, 0.0, 0.68, 0.48, 0.14, 0.12, 0.84], popularity: 0.59, historicalAvgSlot: 7.2 },
  { id: 'm60', title: 'Koyaanisqatsi', year: 1982, category: 'Documentary', tags: ['time-lapse', 'philip-glass', 'non-narrative', 'urban', 'experimental', 'documentary'], vec: [0.25, 0.0, 0.18, 0.10, 0.0, 0.85, 0.15, 0.88, 0.55, 0.18, 0.82, 0.98], popularity: 0.60, historicalAvgSlot: 7.5 },
  { id: 'm61', title: 'Hoop Dreams', year: 1994, category: 'Documentary', tags: ['basketball', 'chicago', 'coming-of-age', 'longitudinal', 'documentary'], vec: [0.0, 0.0, 0.82, 0.25, 0.05, 0.99, 0.0, 0.52, 0.08, 0.32, 0.66, 0.12], popularity: 0.64, historicalAvgSlot: 6.7 },
  { id: 'm62', title: 'Flee', year: 2021, category: 'Documentary', tags: ['animation', 'refugee', 'memory', 'afghanistan', 'intimate', 'documentary'], vec: [0.0, 0.05, 0.82, 0.38, 0.0, 0.92, 0.86, 0.58, 0.22, 0.22, 0.05, 0.45], popularity: 0.61, historicalAvgSlot: 6.9 },

  // Animation / Visual
  { id: 'm63', title: 'Spirited Away', year: 2001, category: 'Animation', tags: ['ghibli', 'fantasy', 'coming-of-age', 'hand-drawn', 'folklore', 'animation'], vec: [0.15, 0.08, 0.64, 0.22, 0.25, 0.0, 0.99, 0.52, 0.32, 0.86, 0.42, 0.45], popularity: 0.94, historicalAvgSlot: 1.5 },
  { id: 'm64', title: 'Spider-Man: Into the Spider-Verse', year: 2018, category: 'Animation', tags: ['multiverse', 'comic-book', 'brooklyn', 'kinetic', 'sci-fi', 'animation'], vec: [0.65, 0.12, 0.42, 0.58, 0.48, 0.0, 0.99, 0.08, 0.48, 0.94, 0.08, 0.52], popularity: 0.94, historicalAvgSlot: 1.4 },
  { id: 'm65', title: 'Paprika', year: 2006, category: 'Animation', tags: ['dreams', 'satoshi-kon', 'surreal', 'nonlinear', 'sci-fi', 'animation'], vec: [0.74, 0.28, 0.25, 0.52, 0.12, 0.0, 0.98, 0.28, 0.88, 0.32, 0.34, 0.86], popularity: 0.72, historicalAvgSlot: 5.6 },
  { id: 'm66', title: 'Princess Mononoke', year: 1997, category: 'Animation', tags: ['ecology', 'ghibli', 'epic', 'folklore', 'hand-drawn', 'animation'], vec: [0.12, 0.15, 0.68, 0.48, 0.05, 0.0, 0.98, 0.45, 0.22, 0.74, 0.58, 0.38], popularity: 0.88, historicalAvgSlot: 2.5 },
  { id: 'm67', title: 'Perfect Blue', year: 1997, category: 'Animation', tags: ['psychological', 'identity', 'pop-idol', 'satoshi-kon', 'thriller', 'animation'], vec: [0.10, 0.74, 0.48, 0.86, 0.0, 0.0, 0.96, 0.32, 0.86, 0.28, 0.56, 0.72], popularity: 0.76, historicalAvgSlot: 4.7 },
  { id: 'm68', title: 'WALL-E', year: 2008, category: 'Animation', tags: ['robot', 'space', 'silent-first-act', 'ecology', 'sci-fi', 'animation'], vec: [0.84, 0.02, 0.58, 0.15, 0.38, 0.0, 0.96, 0.42, 0.15, 0.92, 0.28, 0.22], popularity: 0.93, historicalAvgSlot: 1.7 },

  // Comedy / Satire / Light
  { id: 'm69', title: 'The Grand Budapest Hotel', year: 2014, category: 'Comedy', tags: ['symmetry', 'wes-anderson', 'capers', 'nostalgia', 'ensemble', 'satire'], vec: [0.0, 0.18, 0.48, 0.25, 0.92, 0.0, 0.25, 0.25, 0.38, 0.74, 0.45, 0.42], popularity: 0.89, historicalAvgSlot: 2.0 },
  { id: 'm70', title: 'In Bruges', year: 2008, category: 'Comedy', tags: ['dark-comedy', 'hitmen', 'belgium', 'dialogue', 'melancholy', 'crime'], vec: [0.0, 0.45, 0.62, 0.48, 0.86, 0.0, 0.0, 0.42, 0.15, 0.48, 0.24, 0.18], popularity: 0.82, historicalAvgSlot: 3.2 },
  { id: 'm71', title: 'Dr. Strangelove', year: 1964, category: 'Comedy', tags: ['cold-war', 'satire', 'black-and-white', 'kubrick', 'nuclear', 'comedy'], vec: [0.22, 0.15, 0.25, 0.35, 0.95, 0.0, 0.0, 0.28, 0.32, 0.56, 0.98, 0.38], popularity: 0.83, historicalAvgSlot: 3.4 },
  { id: 'm72', title: 'The Big Lebowski', year: 1998, category: 'Comedy', tags: ['bowling', 'los-angeles', 'stoner-noir', 'coen-brothers', 'cult', 'comedy'], vec: [0.0, 0.48, 0.25, 0.18, 0.96, 0.0, 0.0, 0.32, 0.28, 0.78, 0.66, 0.32], popularity: 0.91, historicalAvgSlot: 1.8 },
  { id: 'm73', title: 'Palm Springs', year: 2020, category: 'Comedy', tags: ['time-loop', 'wedding', 'rom-com', 'sci-fi', 'desert', 'comedy'], vec: [0.48, 0.02, 0.38, 0.10, 0.92, 0.0, 0.0, 0.18, 0.42, 0.62, 0.05, 0.18], popularity: 0.76, historicalAvgSlot: 4.6 },
  { id: 'm74', title: 'Everything Everywhere All at Once', year: 2022, category: 'Sci-Fi', tags: ['multiverse', 'family', 'martial-arts', 'absurdist', 'sci-fi', 'nonlinear'], vec: [0.86, 0.05, 0.68, 0.52, 0.65, 0.0, 0.18, 0.08, 0.88, 0.88, 0.05, 0.72], popularity: 0.93, historicalAvgSlot: 1.6 },
  { id: 'm75', title: 'Tenet', year: 2020, category: 'Sci-Fi', tags: ['time-inversion', 'espionage', 'nonlinear', 'blockbuster', 'sci-fi', 'puzzle'], vec: [0.88, 0.22, 0.18, 0.82, 0.0, 0.0, 0.0, 0.18, 0.96, 0.88, 0.05, 0.42], popularity: 0.82, historicalAvgSlot: 3.1 },
  { id: 'm76', title: 'Predestination', year: 2014, category: 'Sci-Fi', tags: ['time-travel', 'paradox', 'neo-noir', 'twist', 'sci-fi', 'puzzle'], vec: [0.90, 0.56, 0.35, 0.66, 0.0, 0.0, 0.0, 0.38, 0.96, 0.32, 0.14, 0.48], popularity: 0.71, historicalAvgSlot: 5.7 },
  { id: 'm77', title: 'Looper', year: 2012, category: 'Sci-Fi', tags: ['time-travel', 'hitman', 'neo-noir', 'dystopian', 'sci-fi', 'action'], vec: [0.86, 0.62, 0.35, 0.78, 0.0, 0.0, 0.0, 0.25, 0.62, 0.70, 0.16, 0.22], popularity: 0.80, historicalAvgSlot: 3.5 },
  { id: 'm78', title: 'The Prestige', year: 2006, category: 'Thriller', tags: ['magicians', 'victorian', 'obsession', 'nonlinear', 'twist', 'sci-fi'], vec: [0.42, 0.68, 0.58, 0.84, 0.0, 0.0, 0.0, 0.38, 0.90, 0.86, 0.34, 0.28], popularity: 0.92, historicalAvgSlot: 1.6 },
  { id: 'm79', title: 'Vertigo', year: 1958, category: 'Noir', tags: ['obsession', 'san-francisco', 'hitchcock', 'psychological', 'classic-noir', 'mystery'], vec: [0.0, 0.90, 0.64, 0.72, 0.0, 0.0, 0.0, 0.72, 0.58, 0.55, 0.99, 0.42], popularity: 0.84, historicalAvgSlot: 2.9 },
  { id: 'm80', title: 'Fargo', year: 1996, category: 'Noir', tags: ['minnesota', 'snow', 'kidnapping', 'coen-brothers', 'dark-comedy', 'crime'], vec: [0.0, 0.68, 0.52, 0.74, 0.56, 0.08, 0.0, 0.38, 0.15, 0.74, 0.66, 0.18], popularity: 0.88, historicalAvgSlot: 2.2 },
];

interface RawOttoSpec {
  id: string;
  title: string;
  year: number;
  category: string;
  tags: string[];
  vec: number[];
  popularity: number;
  historicalAvgSlot: number;
  baseConversionRate: number;
  cartRate: number;
  orderGivenCartRate: number;
}

const RAW_OTTO: RawOttoSpec[] = [
  // Audio & Studio Hardware
  { id: 'o01', title: 'Focal Alpha 65 Evo Studio Monitor', year: 2024, category: 'Studio Audio', tags: ['studio-monitor', 'active-speaker', 'reference-audio', 'xlr', 'mixing', 'acoustics'], vec: [0.95, 0.20, 0.15, 0.10, 0.05, 0.80, 0.10, 0.60, 0.40, 0.55, 0.20, 0.35], popularity: 0.82, historicalAvgSlot: 2.1, baseConversionRate: 0.048, cartRate: 0.21, orderGivenCartRate: 0.36 },
  { id: 'o02', title: 'Universal Audio Volt 276 Interface', year: 2024, category: 'Studio Audio', tags: ['audio-interface', 'usb-c', 'preamp', 'compressor', 'recording', 'xlr'], vec: [0.94, 0.18, 0.12, 0.10, 0.05, 0.76, 0.05, 0.55, 0.35, 0.68, 0.18, 0.25], popularity: 0.88, historicalAvgSlot: 1.5, baseConversionRate: 0.056, cartRate: 0.24, orderGivenCartRate: 0.39 },
  { id: 'o03', title: 'Sennheiser HD 650 Open-Back Headphones', year: 2023, category: 'Studio Audio', tags: ['open-back', 'audiophile', 'reference-audio', 'mixing', 'studio-headphones'], vec: [0.92, 0.15, 0.18, 0.08, 0.0, 0.72, 0.05, 0.70, 0.30, 0.78, 0.65, 0.20], popularity: 0.91, historicalAvgSlot: 1.3, baseConversionRate: 0.062, cartRate: 0.26, orderGivenCartRate: 0.41 },
  { id: 'o04', title: 'Shure SM7dB Active Dynamic Mic', year: 2024, category: 'Studio Audio', tags: ['microphone', 'xlr', 'podcast', 'vocal-booth', 'preamp', 'broadcast'], vec: [0.90, 0.12, 0.10, 0.12, 0.10, 0.68, 0.05, 0.45, 0.25, 0.86, 0.42, 0.15], popularity: 0.93, historicalAvgSlot: 1.2, baseConversionRate: 0.059, cartRate: 0.25, orderGivenCartRate: 0.40 },
  { id: 'o05', title: 'Teenage Engineering TP-7 Field Recorder', year: 2024, category: 'Studio Audio', tags: ['field-recorder', 'portable', 'industrial-design', 'minimalist', 'audio'], vec: [0.85, 0.10, 0.20, 0.05, 0.05, 0.50, 0.85, 0.50, 0.65, 0.34, 0.10, 0.92], popularity: 0.64, historicalAvgSlot: 6.2, baseConversionRate: 0.036, cartRate: 0.16, orderGivenCartRate: 0.33 },
  { id: 'o06', title: 'IsoAcoustics ISO-155 Isolation Stands', year: 2023, category: 'Studio Audio', tags: ['speaker-stands', 'acoustics', 'desk-mount', 'studio-monitor', 'damping'], vec: [0.88, 0.10, 0.05, 0.05, 0.0, 0.78, 0.05, 0.40, 0.20, 0.52, 0.15, 0.18], popularity: 0.71, historicalAvgSlot: 4.8, baseConversionRate: 0.074, cartRate: 0.31, orderGivenCartRate: 0.44 },

  // Mechanical Keyboards & Desk Hardware
  { id: 'o07', title: 'Keychron Q1 Pro QMK Mechanical Keyboard', year: 2024, category: 'Desk Hardware', tags: ['mechanical-keyboard', 'gasket-mount', 'aluminum', 'wireless', 'qmk-via', 'tactile'], vec: [0.42, 0.85, 0.22, 0.15, 0.05, 0.45, 0.40, 0.35, 0.55, 0.82, 0.12, 0.35], popularity: 0.92, historicalAvgSlot: 1.4, baseConversionRate: 0.064, cartRate: 0.27, orderGivenCartRate: 0.42 },
  { id: 'o08', title: 'Mode Envoy 65% Custom Keyboard Kit', year: 2024, category: 'Desk Hardware', tags: ['mechanical-keyboard', 'custom-kit', 'brass-weight', 'lattice-mount', 'enthusiast'], vec: [0.30, 0.94, 0.25, 0.10, 0.0, 0.38, 0.55, 0.48, 0.78, 0.32, 0.10, 0.74], popularity: 0.61, historicalAvgSlot: 6.5, baseConversionRate: 0.041, cartRate: 0.18, orderGivenCartRate: 0.37 },
  { id: 'o09', title: 'GMK Dualshot R2 PBT Keycap Set', year: 2023, category: 'Desk Hardware', tags: ['keycaps', 'mechanical-keyboard', 'retro-gray', 'cherry-profile', 'desk-setup'], vec: [0.25, 0.88, 0.15, 0.05, 0.12, 0.20, 0.62, 0.35, 0.40, 0.48, 0.68, 0.45], popularity: 0.68, historicalAvgSlot: 5.1, baseConversionRate: 0.058, cartRate: 0.25, orderGivenCartRate: 0.38 },
  { id: 'o10', title: 'Logitech MX Master 3S Ergonomic Mouse', year: 2023, category: 'Desk Hardware', tags: ['ergonomic-mouse', 'quiet-click', 'usb-c', 'productivity', 'desk-setup'], vec: [0.35, 0.78, 0.15, 0.10, 0.05, 0.65, 0.20, 0.25, 0.20, 0.96, 0.15, 0.10], popularity: 0.96, historicalAvgSlot: 1.1, baseConversionRate: 0.078, cartRate: 0.32, orderGivenCartRate: 0.46 },
  { id: 'o11', title: 'BenQ ScreenBar Halo Monitor Light', year: 2024, category: 'Desk Hardware', tags: ['desk-lighting', 'bias-light', 'wireless-puck', 'ergonomic', 'minimalist'], vec: [0.32, 0.75, 0.20, 0.05, 0.0, 0.55, 0.35, 0.45, 0.25, 0.79, 0.08, 0.22], popularity: 0.84, historicalAvgSlot: 2.3, baseConversionRate: 0.068, cartRate: 0.28, orderGivenCartRate: 0.43 },
  { id: 'o12', title: 'CalDigit TS4 Thunderbolt 4 Dock', year: 2024, category: 'Desk Hardware', tags: ['thunderbolt-4', 'usb-c-hub', '18-port', '98w-charging', 'workstation'], vec: [0.48, 0.82, 0.10, 0.10, 0.0, 0.85, 0.15, 0.30, 0.42, 0.80, 0.10, 0.18], popularity: 0.85, historicalAvgSlot: 2.0, baseConversionRate: 0.054, cartRate: 0.22, orderGivenCartRate: 0.38 },

  // Specialty Espresso & Kitchen
  { id: 'o13', title: 'Fellow Ode Gen 2 Brew Grinder', year: 2024, category: 'Espresso', tags: ['coffee-grinder', 'flat-burr', 'pour-over', 'matte-black', 'precision'], vec: [0.10, 0.12, 0.94, 0.15, 0.10, 0.55, 0.42, 0.72, 0.40, 0.74, 0.12, 0.30], popularity: 0.87, historicalAvgSlot: 1.8, baseConversionRate: 0.061, cartRate: 0.25, orderGivenCartRate: 0.41 },
  { id: 'o14', title: 'Profitec GO Single Boiler Espresso Machine', year: 2024, category: 'Espresso', tags: ['espresso-machine', 'pid-control', '58mm-portafilter', 'brass-boiler', 'barista'], vec: [0.08, 0.10, 0.96, 0.12, 0.0, 0.62, 0.25, 0.82, 0.52, 0.56, 0.28, 0.35], popularity: 0.79, historicalAvgSlot: 3.1, baseConversionRate: 0.044, cartRate: 0.18, orderGivenCartRate: 0.35 },
  { id: 'o15', title: 'Acaia Lunar Espresso Scale', year: 2023, category: 'Espresso', tags: ['coffee-scale', 'waterproof', 'flow-rate', 'barista', 'precision', 'usb-c'], vec: [0.15, 0.18, 0.92, 0.08, 0.0, 0.70, 0.35, 0.65, 0.48, 0.52, 0.15, 0.42], popularity: 0.75, historicalAvgSlot: 3.9, baseConversionRate: 0.066, cartRate: 0.27, orderGivenCartRate: 0.42 },
  { id: 'o16', title: 'Fellow Stagg EKG Pro Electric Kettle', year: 2024, category: 'Espresso', tags: ['gooseneck-kettle', 'pour-over', 'temperature-hold', 'matte-black', 'minimalist'], vec: [0.08, 0.15, 0.91, 0.05, 0.08, 0.48, 0.48, 0.74, 0.25, 0.83, 0.10, 0.25], popularity: 0.89, historicalAvgSlot: 1.7, baseConversionRate: 0.069, cartRate: 0.29, orderGivenCartRate: 0.44 },
  { id: 'o17', title: 'Niche Zero Conical Burr Grinder', year: 2023, category: 'Espresso', tags: ['single-dose', 'coffee-grinder', 'espresso', 'low-retention', 'barista'], vec: [0.05, 0.10, 0.95, 0.08, 0.0, 0.58, 0.30, 0.80, 0.46, 0.60, 0.22, 0.40], popularity: 0.77, historicalAvgSlot: 3.4, baseConversionRate: 0.049, cartRate: 0.20, orderGivenCartRate: 0.37 },
  { id: 'o18', title: 'V60 Ceramic Dripper & Carafe Kit', year: 2023, category: 'Espresso', tags: ['pour-over', 'ceramic', 'manual-brew', 'filter-coffee', 'minimalist'], vec: [0.02, 0.08, 0.88, 0.02, 0.12, 0.35, 0.25, 0.78, 0.15, 0.72, 0.48, 0.15], popularity: 0.84, historicalAvgSlot: 2.5, baseConversionRate: 0.092, cartRate: 0.36, orderGivenCartRate: 0.52 },

  // Cameras & Optics
  { id: 'o19', title: 'Fujifilm X100VI Compact Camera', year: 2024, category: 'Cameras', tags: ['rangefinder', 'film-simulation', '35mm-equiv', 'street-photography', 'ibis'], vec: [0.22, 0.20, 0.25, 0.85, 0.05, 0.40, 0.68, 0.55, 0.45, 0.92, 0.55, 0.48], popularity: 0.95, historicalAvgSlot: 1.2, baseConversionRate: 0.039, cartRate: 0.17, orderGivenCartRate: 0.34 },
  { id: 'o20', title: 'Sony FE 35mm f/1.4 GM Lens', year: 2023, category: 'Cameras', tags: ['prime-lens', 'e-mount', 'low-light', 'cinema', 'bokeh', 'full-frame'], vec: [0.28, 0.18, 0.12, 0.94, 0.0, 0.65, 0.30, 0.45, 0.52, 0.76, 0.18, 0.28], popularity: 0.81, historicalAvgSlot: 2.7, baseConversionRate: 0.042, cartRate: 0.18, orderGivenCartRate: 0.35 },
  { id: 'o21', title: 'Peak Design Everyday Sling 6L', year: 2023, category: 'Cameras', tags: ['camera-bag', 'weatherproof', 'everyday-carry', 'crossbody', 'modular'], vec: [0.15, 0.28, 0.15, 0.78, 0.12, 0.50, 0.25, 0.30, 0.22, 0.84, 0.12, 0.15], popularity: 0.86, historicalAvgSlot: 2.2, baseConversionRate: 0.073, cartRate: 0.30, orderGivenCartRate: 0.45 },
  { id: 'o22', title: 'Ricoh GR IIIx Urban Edition', year: 2024, category: 'Cameras', tags: ['pocket-camera', '40mm-equiv', 'street-photography', 'aps-c', 'snap-focus'], vec: [0.18, 0.22, 0.18, 0.88, 0.05, 0.32, 0.45, 0.60, 0.55, 0.64, 0.35, 0.62], popularity: 0.74, historicalAvgSlot: 4.3, baseConversionRate: 0.046, cartRate: 0.19, orderGivenCartRate: 0.36 },
  { id: 'o23', title: 'Tiffen Black Pro-Mist 1/4 67mm Filter', year: 2023, category: 'Cameras', tags: ['lens-filter', 'diffusion', 'halation', 'cinema', 'optics'], vec: [0.15, 0.10, 0.15, 0.82, 0.05, 0.28, 0.42, 0.48, 0.35, 0.68, 0.45, 0.40], popularity: 0.78, historicalAvgSlot: 3.6, baseConversionRate: 0.088, cartRate: 0.35, orderGivenCartRate: 0.50 },
  { id: 'o24', title: 'Sandisk Extreme PRO 256GB UHS-II SD', year: 2024, category: 'Cameras', tags: ['sd-card', '300mb-s', '4k-video', 'storage', 'photography'], vec: [0.25, 0.35, 0.05, 0.76, 0.0, 0.82, 0.05, 0.15, 0.15, 0.90, 0.08, 0.05], popularity: 0.91, historicalAvgSlot: 1.6, baseConversionRate: 0.105, cartRate: 0.41, orderGivenCartRate: 0.56 },

  // Trail & Endurance Gear
  { id: 'o25', title: 'Salomon S/Lab Pulsar 3 Trail Shoe', year: 2024, category: 'Trail Gear', tags: ['trail-running', 'ultralight', 'carbon-plate', 'mountain', 'endurance'], vec: [0.05, 0.05, 0.08, 0.12, 0.94, 0.42, 0.20, 0.20, 0.25, 0.72, 0.05, 0.38], popularity: 0.76, historicalAvgSlot: 3.5, baseConversionRate: 0.051, cartRate: 0.21, orderGivenCartRate: 0.37 },
  { id: 'o26', title: 'Garmin Forerunner 965 GPS Watch', year: 2024, category: 'Trail Gear', tags: ['gps-watch', 'amoled', 'hrv', 'trail-running', 'navigation', 'telemetry'], vec: [0.28, 0.18, 0.05, 0.15, 0.92, 0.84, 0.15, 0.25, 0.45, 0.85, 0.08, 0.25], popularity: 0.88, historicalAvgSlot: 1.9, baseConversionRate: 0.047, cartRate: 0.20, orderGivenCartRate: 0.36 },
  { id: 'o27', title: 'Arc-teryx Norvan Wind Shell', year: 2024, category: 'Trail Gear', tags: ['windbreaker', 'packable', 'alpine', 'trail-running', 'ultralight'], vec: [0.05, 0.08, 0.10, 0.10, 0.90, 0.55, 0.22, 0.30, 0.18, 0.66, 0.10, 0.28], popularity: 0.73, historicalAvgSlot: 4.5, baseConversionRate: 0.055, cartRate: 0.23, orderGivenCartRate: 0.38 },
  { id: 'o28', title: 'Salomon ADV Skin 12 Hydration Vest', year: 2024, category: 'Trail Gear', tags: ['hydration-vest', 'ultra-marathon', 'soft-flask', 'trail-running', 'endurance'], vec: [0.02, 0.05, 0.08, 0.10, 0.95, 0.60, 0.10, 0.25, 0.20, 0.79, 0.12, 0.18], popularity: 0.84, historicalAvgSlot: 2.4, baseConversionRate: 0.068, cartRate: 0.28, orderGivenCartRate: 0.44 },
  { id: 'o29', title: 'Black Diamond Distance Carbon Z Poles', year: 2023, category: 'Trail Gear', tags: ['trekking-poles', 'carbon-fiber', 'foldable', 'alpine', 'ultralight'], vec: [0.05, 0.05, 0.05, 0.08, 0.92, 0.65, 0.10, 0.32, 0.22, 0.58, 0.15, 0.25], popularity: 0.69, historicalAvgSlot: 5.0, baseConversionRate: 0.059, cartRate: 0.24, orderGivenCartRate: 0.40 },
  { id: 'o30', title: 'Maurten Gel 100 Hydrogel Pack (12x)', year: 2024, category: 'Trail Gear', tags: ['nutrition', 'endurance', 'marathon', 'carbohydrates', 'trail-running'], vec: [0.02, 0.02, 0.10, 0.02, 0.88, 0.52, 0.02, 0.15, 0.10, 0.82, 0.05, 0.12], popularity: 0.85, historicalAvgSlot: 2.6, baseConversionRate: 0.118, cartRate: 0.44, orderGivenCartRate: 0.59 },
];

function buildCoVisitEdges(items: CatalogItem[], seed: number): CatalogItem[] {
  const rng = createRng(seed);
  return items.map((item) => {
    const scored = items
      .filter((other) => other.id !== item.id)
      .map((other) => {
        const sim = cosineSimilarity(item.embedding, other.embedding);
        const sameCatBonus = item.category === other.category ? 0.14 : 0;
        const popFactor = 0.25 * other.popularity;
        const noise = (rng() - 0.5) * 0.06;
        return {
          itemId: other.id,
          weight: Math.max(0.01, sim * 0.72 + sameCatBonus + popFactor + noise),
        };
      })
      .sort((a, b) => b.weight - a.weight)
      .slice(0, 6);
    return { ...item, coVisitNeighbors: scored };
  });
}

export const MOVIELENS_CATALOG: CatalogItem[] = buildCoVisitEdges(
  RAW_MOVIES.map((m) => ({
    id: m.id,
    title: m.title,
    subtitle: `${m.year} · ${m.category}`,
    year: m.year,
    category: m.category,
    tags: m.tags,
    embedding: normalize(m.vec),
    popularity: m.popularity,
    recency: Math.max(0.05, Math.min(1, (m.year - 1940) / (2025 - 1940))),
    historicalAvgSlot: m.historicalAvgSlot,
    baseConversionRate: 0.06 + 0.05 * m.popularity,
    cartRate: 0.22 + 0.08 * m.popularity,
    orderGivenCartRate: 0.45,
    coVisitNeighbors: [],
  })),
  20261118
);

export const OTTO_CATALOG: CatalogItem[] = buildCoVisitEdges(
  RAW_OTTO.map((o) => ({
    id: o.id,
    title: o.title,
    subtitle: `${o.category} · ${o.year}`,
    year: o.year,
    category: o.category,
    tags: o.tags,
    embedding: normalize(o.vec),
    popularity: o.popularity,
    recency: o.year >= 2024 ? 0.92 : 0.74,
    historicalAvgSlot: o.historicalAvgSlot,
    baseConversionRate: o.baseConversionRate,
    cartRate: o.cartRate,
    orderGivenCartRate: o.orderGivenCartRate,
    coVisitNeighbors: [],
  })),
  99118822
);

export const MOVIELENS_USERS: UserProfile[] = [
  {
    id: 'u_noir',
    label: 'User #4091 — Classic Noir & Indie Drama',
    persona: 'Deep long-term affinity for 1970s–2000s neo-noir and slow-burn character dramas. Zero historical Sci-Fi.',
    historySummary: '142 historical watches · Chinatown, The Conversation, Moonlight, In the Mood for Love',
    truePreference: normalize([0.05, 0.88, 0.82, 0.42, 0.05, 0.12, 0.02, 0.78, 0.45, 0.28, 0.76, 0.42]),
    historyItemIds: ['m23', 'm25', 'm27', 'm29', 'm35', 'm37', 'm38', 'm46'],
    preExperimentRate: 0.118,
    sessionSeedCategory: 'Noir',
  },
  {
    id: 'u_scifi',
    label: 'User #8812 — Hard Sci-Fi & Cerebral Puzzles',
    persona: 'Consistent affinity for speculative AI, time-loops, and nonlinear architecture.',
    historySummary: '98 historical watches · Arrival, Ex Machina, Primer, Blade Runner 2049',
    truePreference: normalize([0.96, 0.34, 0.35, 0.52, 0.04, 0.05, 0.18, 0.62, 0.88, 0.42, 0.35, 0.62]),
    historyItemIds: ['m01', 'm02', 'm03', 'm05', 'm08', 'm11', 'm13'],
    preExperimentRate: 0.142,
    sessionSeedCategory: 'Sci-Fi',
  },
  {
    id: 'u_thriller',
    label: 'User #1704 — High-Tension Crime & Satire',
    persona: 'Fast-paced thrillers, heist procedurals, and dark social satires.',
    historySummary: '214 historical watches · Parasite, Sicario, Heat, No Country for Old Men',
    truePreference: normalize([0.12, 0.62, 0.45, 0.94, 0.28, 0.08, 0.05, 0.22, 0.35, 0.78, 0.24, 0.20]),
    historyItemIds: ['m47', 'm48', 'm49', 'm51', 'm53', 'm54'],
    preExperimentRate: 0.131,
    sessionSeedCategory: 'Thriller',
  },
  {
    id: 'u_cold',
    label: 'User #9031 — Cold-Start Sparse Profile',
    persona: 'New account with only 2 historical watches; relies almost entirely on session gate g and tag/BM25 match.',
    historySummary: '2 historical watches · Free Solo, Spirited Away',
    truePreference: normalize([0.25, 0.15, 0.45, 0.35, 0.15, 0.55, 0.62, 0.45, 0.32, 0.68, 0.15, 0.25]),
    historyItemIds: ['m57', 'm63'],
    preExperimentRate: 0.078,
    sessionSeedCategory: 'Documentary',
  },
];

export const OTTO_USERS: UserProfile[] = [
  {
    id: 'o_u1',
    label: 'Shopper #6120 — Workstation & Mechanical Keys',
    persona: 'Historical buyer of ergonomic desk hardware, QMK keyboards, and Thunderbolt docks.',
    historySummary: '19 past orders · Keychron Q1 Pro, CalDigit TS4, MX Master 3S',
    truePreference: normalize([0.32, 0.90, 0.18, 0.10, 0.02, 0.65, 0.35, 0.35, 0.48, 0.78, 0.15, 0.32]),
    historyItemIds: ['o07', 'o10', 'o11', 'o12'],
    preExperimentRate: 0.068,
    sessionSeedCategory: 'Desk Hardware',
  },
  {
    id: 'o_u2',
    label: 'Shopper #3348 — Specialty Barista & Home Cafe',
    persona: 'Deep affinity for precision pour-over, flat-burr grinders, and PID espresso machines.',
    historySummary: '14 past orders · Fellow Ode Gen 2, Acaia Lunar, V60 Kit',
    truePreference: normalize([0.08, 0.12, 0.96, 0.08, 0.04, 0.58, 0.36, 0.78, 0.40, 0.66, 0.22, 0.32]),
    historyItemIds: ['o13', 'o15', 'o16', 'o18'],
    preExperimentRate: 0.074,
    sessionSeedCategory: 'Espresso',
  },
  {
    id: 'o_u3',
    label: 'Shopper #7782 — Street Photographer & Studio Audio',
    persona: 'Hybrid creator buying prime optics, diffusion filters, and XLR voiceover gear.',
    historySummary: '11 past orders · Fujifilm X100VI, Shure SM7dB, Peak Design Sling',
    truePreference: normalize([0.58, 0.18, 0.15, 0.68, 0.05, 0.65, 0.35, 0.48, 0.42, 0.78, 0.32, 0.34]),
    historyItemIds: ['o04', 'o19', 'o21', 'o23'],
    preExperimentRate: 0.059,
    sessionSeedCategory: 'Cameras',
  },
  {
    id: 'o_u4',
    label: 'Shopper #1055 — Cold-Start Trail Runner',
    persona: 'Minimal past purchase history (1 order); session clicks drive rapid intent adaptation.',
    historySummary: '1 past order · Maurten Hydrogel Pack',
    truePreference: normalize([0.08, 0.08, 0.08, 0.12, 0.94, 0.62, 0.15, 0.25, 0.22, 0.75, 0.08, 0.24]),
    historyItemIds: ['o30'],
    preExperimentRate: 0.052,
    sessionSeedCategory: 'Trail Gear',
  },
];

export function getCatalog(mode: DatasetMode): CatalogItem[] {
  return mode === 'movielens' ? MOVIELENS_CATALOG : OTTO_CATALOG;
}

export function getUsers(mode: DatasetMode): UserProfile[] {
  return mode === 'movielens' ? MOVIELENS_USERS : OTTO_USERS;
}

export function getInjectableCategory(mode: DatasetMode): {
  label: string;
  category: string;
  items: CatalogItem[];
} {
  if (mode === 'movielens') {
    const items = MOVIELENS_CATALOG.filter((i) => i.category === 'Sci-Fi');
    return { label: 'Sci-Fi', category: 'Sci-Fi', items };
  }
  const items = OTTO_CATALOG.filter((i) => i.category === 'Studio Audio');
  return { label: 'Studio Audio', category: 'Studio Audio', items };
}
