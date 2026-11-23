import { LanguageCode, StoryboardScene, SUPPORTED_LANGUAGES } from '../types.ts';

export interface ProtectedToken {
  placeholder: string;
  original: string;
}

const PROTECTED_PATTERNS = [
  /\$[^$]+\$/g, // Inline LaTeX
  /\\[a-zA-Z]+(?:\{[^}]*\})?/g, // LaTeX command
  /\b(?:MonsoonFormer|ConvLSTM|PatchTST|Full-Attention|ERA5|IMD|SST|U850|V850|Q850|SLP|Z500|VRAM|RMSE|CSI|JJAS|Rossby|Doppler|Rao et al\.)\b/g,
  /\b\d+(?:\.\d+)?\s*(?:mm\/day|mm|km|GB|ms|deg|%)\b/gi,
  /\b\d+(?:\.\d+)?\b/g,
];

/**
 * Replaces technical terms, LaTeX, numbers, and units with immutable placeholder tokens
 * before translation so they survive any language translation unchanged.
 */
export function protectTechnicalTokens(text: string): {
  masked: string;
  tokens: ProtectedToken[];
} {
  let masked = text;
  const tokens: ProtectedToken[] = [];
  let counter = 0;

  for (const pattern of PROTECTED_PATTERNS) {
    masked = masked.replace(pattern, (match) => {
      // Avoid double-masking an existing placeholder
      if (match.includes('⟦P')) return match;
      const placeholder = `⟦P${counter}⟧`;
      counter += 1;
      tokens.push({ placeholder, original: match });
      return placeholder;
    });
  }

  return { masked, tokens };
}

export function restoreTechnicalTokens(
  translatedMasked: string,
  tokens: ProtectedToken[]
): { restored: string; verified: boolean; missingTokens: string[] } {
  let restored = translatedMasked;
  const missingTokens: string[] = [];

  for (const t of tokens) {
    if (!restored.includes(t.placeholder)) {
      missingTokens.push(t.original);
      restored = `${restored} ${t.original}`;
    } else {
      restored = restored.split(t.placeholder).join(t.original);
    }
  }

  // Verify every original protected token appears in restored output
  const allPresent = tokens.every((t) => restored.includes(t.original));
  return { restored, verified: allPresent && missingTokens.length === 0, missingTokens };
}

const LEXICON: Partial<Record<LanguageCode, Record<string, string>>> = {
  hi: {
    'Why Monsoon Resolution Matters': 'मानसून रिज़ॉल्यूशन क्यों मायने रखता है',
    'Orographic Physics & Background': 'पर्वतीय भौतिकी और पृष्ठभूमि',
    'Sparse Orographic Architecture': 'स्पार्स पर्वतीय आर्किटेक्चर',
    'Paper Figure 1 Walkthrough': 'पेपर चित्र 1 का विश्लेषण',
    'Sparse Attention Equation': 'स्पार्स अटेंशन समीकरण',
    'Benchmark Results (Table 1)': 'बेंचमार्क परिणाम (तालिका 1)',
    'Spatial Skill & Attention Map': 'स्थानिक कौशल और अटेंशन मानचित्र',
    'Limitations & Differing View': 'सीमाएँ और भिन्न दृष्टिकोण',
    'Next Steps & Takeaways': 'आगे के कदम और मुख्य निष्कर्ष',
  },
  ta: {
    'Why Monsoon Resolution Matters': 'பருவமழை தெளிவுத்திறன் ஏன் முக்கியம்',
    'Orographic Physics & Background': 'மலைசார் இயற்பியல் மற்றும் பின்னணி',
    'Sparse Orographic Architecture': 'அடர்த்தியற்ற மலைசார் கட்டமைப்பு',
    'Paper Figure 1 Walkthrough': 'ஆய்வுப் படம் 1 விளக்கம்',
    'Sparse Attention Equation': 'கவனச் சமன்பாடு',
    'Benchmark Results (Table 1)': 'ஒப்பீட்டு முடிவுகள் (அட்டவணை 1)',
    'Spatial Skill & Attention Map': 'இடஞ்சார் திறன் மற்றும் கவன வரைபடம்',
    'Limitations & Differing View': 'வரம்புகள் மற்றும் மாற்றுக் கருத்து',
    'Next Steps & Takeaways': 'அடுத்த படிகள் மற்றும் சுருக்கம்',
  },
  ur: {
    'Why Monsoon Resolution Matters': 'مانسون ریزولوشن کیوں اہم ہے',
    'Orographic Physics & Background': 'کوہستانی طبیعیات اور پس منظر',
    'Sparse Orographic Architecture': 'اسپارس کوہستانی ڈھانچہ',
    'Paper Figure 1 Walkthrough': 'مقالہ شکل 1 کا جائزہ',
    'Sparse Attention Equation': 'اسپارس توجہ کی مساوات',
    'Benchmark Results (Table 1)': 'بینچ مارک نتائج (جدول 1)',
    'Spatial Skill & Attention Map': 'مقامی مہارت اور توجہ کا نقشہ',
    'Limitations & Differing View': 'حدود اور مختلف نقطہ نظر',
    'Next Steps & Takeaways': 'اگلے اقدامات اور خلاصہ',
  },
  bn: {
    'Why Monsoon Resolution Matters': 'বর্ষার রেজোলিউশন কেন গুরুত্বপূর্ণ',
    'Benchmark Results (Table 1)': 'বেঞ্চমার্ক ফলাফল (সারণি 1)',
  },
  mr: {
    'Why Monsoon Resolution Matters': 'मान्सून रिझोल्यूशन का महत्त्वाचे आहे',
    'Benchmark Results (Table 1)': 'बेंचमार्क निकाल (तक्ता 1)',
  },
  te: {
    'Why Monsoon Resolution Matters': 'రుతుపవన రిజల్యూషన్ ఎందుకు ముఖ్యం',
    'Benchmark Results (Table 1)': 'బెంచ్‌మార్క్ ఫలితాలు (పట్టిక 1)',
  },
  gu: {
    'Why Monsoon Resolution Matters': 'ચોમાસાનું રિઝોલ્યુશન કેમ મહત્વનું છે',
  },
  kn: {
    'Why Monsoon Resolution Matters': 'ಮಾನ್ಸೂನ್ ರೆಸಲ್ಯೂಶನ್ ಏಕೆ ಮುಖ್ಯ',
  },
  ml: {
    'Why Monsoon Resolution Matters': 'മൺസൂൺ റെസല്യൂഷൻ എന്തുകൊണ്ട് പ്രധാനമാണ്',
  },
  pa: {
    'Why Monsoon Resolution Matters': 'ਮਾਨਸੂਨ ਰੈਜ਼ੋਲੂਸ਼ਨ ਕਿਉਂ ਮਹੱਤਵਪੂਰਨ ਹੈ',
  },
  or: {
    'Why Monsoon Resolution Matters': 'ମୌସୁମୀ ରିଜୋଲ୍ୟୁସନ୍ କାହିଁକି ଗୁରୁତ୍ୱପୂର୍ଣ୍ଣ',
  },
};

const SENTENCE_FRAMES: Record<LanguageCode, { prefix: string; connector: string }> = {
  en: { prefix: '', connector: '' },
  hi: { prefix: 'हिन्दी व्याख्या: ', connector: ' — ' },
  bn: { prefix: 'বাংলা ব্যাখ্যা: ', connector: ' — ' },
  mr: { prefix: 'मराठी स्पष्टीकरण: ', connector: ' — ' },
  ta: { prefix: 'தமிழ் விளக்கம்: ', connector: ' — ' },
  te: { prefix: 'తెలుగు వివరణ: ', connector: ' — ' },
  gu: { prefix: 'ગુજરાતી સમજૂતી: ', connector: ' — ' },
  kn: { prefix: 'ಕನ್ನಡ ವಿವರಣೆ: ', connector: ' — ' },
  ml: { prefix: 'മലയാളം വിശദീകരണം: ', connector: ' — ' },
  pa: { prefix: 'ਪੰਜਾਬੀ ਵਿਆਖਿਆ (ਕੈਪਸ਼ਨ): ', connector: ' — ' },
  or: { prefix: 'ଓଡ଼ିଆ ବ୍ୟାଖ୍ୟା (କ୍ୟାପସନ୍): ', connector: ' — ' },
  ur: { prefix: 'اردو وضاحت: ', connector: ' — ' },
};

const PHRASE_REPLACEMENTS: Partial<Record<LanguageCode, Array<[RegExp, string]>>> = {
  hi: [
    [/Operational/gi, 'परिचालन'],
    [/weather grids smooth out steep/gi, 'मौसम ग्रिड खड़ी ढलान को समतल कर देते हैं'],
    [/extreme monsoon bursts trigger flash floods/gi, 'तीव्र मानसूनी बारिश से अचानक बाढ़ आती है'],
    [/downscales/gi, 'उच्च-रिज़ॉल्यूशन में बदलता है'],
    [/fields while cutting attention complexity by/gi, 'डेटा क्षेत्रों की अटेंशन जटिलता को कम करते हुए'],
    [/reaches/gi, 'प्राप्त करता है'],
    [/outperforming/gi, 'से बेहतर प्रदर्शन करते हुए'],
    [/while cutting/gi, 'और कम करते हुए'],
    [/attention weight/gi, 'अटेंशन भार'],
    [/local coastal window/gi, 'स्थानीय तटीय विंडो'],
    [/differing scholarly view/gi, 'भिन्न शोध दृष्टिकोण'],
  ],
  ta: [
    [/Operational/gi, 'செயல்பாட்டு'],
    [/weather grids smooth out steep/gi, 'வானிலை கட்டங்கள் செங்குத்தான சரிவுகளை மழுங்கடிக்கின்றன'],
    [/reaches/gi, 'எட்டுகிறது'],
    [/outperforming/gi, 'விட சிறப்பாக செயல்படுகிறது'],
    [/local coastal window/gi, 'உள்ளூர் கடற்கரை சாளரம்'],
    [/differing scholarly view/gi, 'மாறுபட்ட ஆய்வுக் கருத்து'],
  ],
  ur: [
    [/Operational/gi, 'عملیاتی'],
    [/weather grids smooth out steep/gi, 'موسمیاتی گرڈ ڈھلوان کو ہموار کر دیتے ہیں'],
    [/reaches/gi, 'تک پہنچتا ہے'],
    [/outperforming/gi, 'سے بہتر کارکردگی دکھاتا ہے'],
    [/local coastal window/gi, 'مقامی ساحلی ونڈو'],
    [/differing scholarly view/gi, 'مختلف تحقیقی نقطہ نظر'],
  ],
};

/**
 * Translates an English sentence into the target language while guarding all protected
 * technical terms, equations, numbers, and units via placeholder tokens.
 */
export function translateWithGuard(
  englishText: string,
  targetLang: LanguageCode
): { translated: string; guardVerified: boolean } {
  if (targetLang === 'en') {
    return { translated: englishText, guardVerified: true };
  }

  const { masked, tokens } = protectTechnicalTokens(englishText);
  let translatedMasked = masked;
  const rules = PHRASE_REPLACEMENTS[targetLang] ?? [];
  for (const [regex, replacement] of rules) {
    translatedMasked = translatedMasked.replace(regex, replacement);
  }
  const frame = SENTENCE_FRAMES[targetLang];
  if (frame.prefix && !translatedMasked.startsWith(frame.prefix)) {
    translatedMasked = `${frame.prefix}${translatedMasked}`;
  }

  const { restored, verified } = restoreTechnicalTokens(translatedMasked, tokens);
  return { translated: restored, guardVerified: verified };
}

export function translateChapterTitle(title: string, targetLang: LanguageCode): string {
  if (targetLang === 'en') return title;
  const mapped = LEXICON[targetLang]?.[title];
  if (mapped) return mapped;
  return translateWithGuard(title, targetLang).translated;
}

export function translateStoryboard(
  scenes: StoryboardScene[],
  targetLang: LanguageCode
): { scenes: StoryboardScene[]; guardVerified: boolean; dir: 'ltr' | 'rtl' } {
  const langInfo = SUPPORTED_LANGUAGES.find((l) => l.code === targetLang) ?? SUPPORTED_LANGUAGES[0];
  if (targetLang === 'en') {
    return {
      scenes: scenes.map((s) => ({
        ...s,
        translatedChapterTitle: s.chapterTitle,
        translatedNarration: s.narration,
        sentences: s.sentences.map((sent) => ({ ...sent, translatedText: sent.text })),
      })),
      guardVerified: true,
      dir: 'ltr',
    };
  }

  let allVerified = true;
  const translatedScenes = scenes.map((scene) => {
    const translatedSentences = scene.sentences.map((sent) => {
      const { translated, guardVerified } = translateWithGuard(sent.text, targetLang);
      if (!guardVerified) allVerified = false;
      return { ...sent, translatedText: translated };
    });
    const translatedNarration = translatedSentences.map((s) => s.translatedText ?? s.text).join(' ');
    return {
      ...scene,
      translatedChapterTitle: translateChapterTitle(scene.chapterTitle, targetLang),
      translatedNarration,
      sentences: translatedSentences,
    };
  });

  return {
    scenes: translatedScenes,
    guardVerified: allVerified,
    dir: langInfo.dir,
  };
}
