import { Flashcard, AnkiRating } from '../types';

export function calculateSM2(card: Flashcard, rating: AnkiRating): Flashcard {
  let interval = card.interval;
  let repetitions = card.repetitions;
  let easeFactor = card.easeFactor;

  const now = new Date();

  switch (rating) {
    case 'again': {
      repetitions = 0;
      interval = 0; // Due immediately / in current session
      easeFactor = Math.max(1.3, easeFactor - 0.2);
      break;
    }
    case 'hard': {
      if (repetitions === 0) {
        interval = 1;
        repetitions = 1;
      } else {
        interval = Math.max(1, Math.round(interval * 1.2));
      }
      easeFactor = Math.max(1.3, easeFactor - 0.15);
      break;
    }
    case 'good': {
      if (repetitions === 0) {
        interval = 1;
      } else if (repetitions === 1) {
        interval = 6;
      } else {
        interval = Math.max(1, Math.round(interval * easeFactor));
      }
      repetitions += 1;
      break;
    }
    case 'easy': {
      if (repetitions === 0) {
        interval = 3;
      } else if (repetitions === 1) {
        interval = 8;
      } else {
        interval = Math.max(1, Math.round(interval * easeFactor * 1.3));
      }
      repetitions += 1;
      easeFactor = easeFactor + 0.15;
      break;
    }
  }

  // Calculate new due date
  const dueDate = new Date(now);
  if (interval === 0) {
    // 10 minutes later for 'again'
    dueDate.setMinutes(dueDate.getMinutes() + 10);
  } else {
    dueDate.setDate(dueDate.getDate() + interval);
  }

  return {
    ...card,
    interval,
    repetitions,
    easeFactor: Number(easeFactor.toFixed(2)),
    dueDate: dueDate.toISOString(),
    lastReviewed: now.toISOString(),
  };
}

export function getIntervalPreview(card: Flashcard, rating: AnkiRating): string {
  switch (rating) {
    case 'again':
      return '< 10m';
    case 'hard': {
      if (card.repetitions === 0) return '1d';
      const days = Math.max(1, Math.round(card.interval * 1.2));
      return `${days}d`;
    }
    case 'good': {
      if (card.repetitions === 0) return '1d';
      if (card.repetitions === 1) return '6d';
      const days = Math.max(1, Math.round(card.interval * card.easeFactor));
      return `${days}d`;
    }
    case 'easy': {
      if (card.repetitions === 0) return '3d';
      if (card.repetitions === 1) return '8d';
      const days = Math.max(1, Math.round(card.interval * card.easeFactor * 1.3));
      return `${days}d`;
    }
  }
}

export function isCardDue(card: Flashcard): boolean {
  if (!card.dueDate) return true;
  return new Date(card.dueDate).getTime() <= Date.now();
}
