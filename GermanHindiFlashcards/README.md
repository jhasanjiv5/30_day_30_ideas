# German–Hindi Flashcards

A Goethe-level German vocabulary study app with Hindi translations, pronunciation, and Anki-style spaced repetition. Choose a level from A1 to C2, study in either language direction, and build your deck with the included vocabulary or Gemini-generated cards.

View the app in [Google AI Studio](https://ai.studio/apps/295210e3-d6c8-48cd-a5b1-5e74d87d5684).

## Navigate the app

- **Choose a Goethe level:** Use the level selector in the top-left to switch between A1, A2, B1, B2, C1, and C2. The progress indicator shows your position in that level's deck.
- **Choose a study direction:** Use the language switch below the header to study German → Hindi or Hindi → German.
- **Study a card:** Tap the card or press **Space** or **Enter** to reveal the answer. Use the speaker controls to hear pronunciation.
- **Rate your recall:** After revealing the answer, choose **Again**, **Hard**, **Good**, or **Easy**. Ratings update the card's review interval. You can also press **1**, **2**, **3**, or **4**, respectively.
- **Open the top-right tools:**
  - **Generate** (sparkles): create Goethe-level cards with Gemini, optionally focused on a topic.
  - **Deck library** (book): search German words, Hindi meanings, or synonyms; reset a card's review interval or remove it.
  - **Progress** (chart): view study and Anki statistics.
  - **Settings** (gear): choose the Gemini model, toggle auto-pronunciation and haptic feedback, and manage or clear deck progress.
- **Change the display frame:** Use the frame control to switch between the iPhone-style view and the full web layout.

Your deck, selected level, study direction, and preferences are saved in the browser's local storage.

## Run locally

**Prerequisite:** Node.js

1. Install dependencies:

   ```sh
   npm install
   ```

2. Copy `.env.example` to `.env` and set `GEMINI_API_KEY` to a Google Gemini API key. This key is required for generating cards; the included deck can be studied without it.

3. Start the development server:

   ```sh
   npm run dev
   ```

4. Open the local URL printed by the server (usually `http://localhost:3000`).

## Project structure

```text
GermanHindiFlashcards/
├── src/
│   ├── components/          # Navigation, flashcard, rating bar, and modal UI
│   ├── data/
│   │   └── goetheSeedData.ts # Included Goethe vocabulary deck
│   ├── utils/
│   │   ├── audio.ts         # Speech and haptic feedback helpers
│   │   └── sm2.ts           # Spaced-repetition scheduling
│   ├── App.tsx              # Study flow, state, and persistence
│   ├── index.css            # Global styles
│   ├── main.tsx             # React entry point
│   └── types.ts             # Shared app and flashcard types
├── .env.example             # Environment variable template
├── index.html               # HTML entry point
├── server.ts                # Express server and Gemini card-generation API
├── package.json             # Dependencies and scripts
├── tsconfig.json            # TypeScript configuration
└── vite.config.ts           # Vite configuration
```

## Available scripts

- `npm run dev` — start the development server.
- `npm run build` — build the frontend and production server.
- `npm start` — run the production server after building.
- `npm run preview` — preview the Vite production build.
- `npm run lint` — run the TypeScript check.
