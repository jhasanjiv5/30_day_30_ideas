import Foundation

public enum MockFixtures {
    public static func places(forTile tile: GeoTile, language: SaathiLanguage) -> [PlaceCandidate] {
        let all = hampiPlaces(tileID: tile.id, lang: language)
            + oldDelhiPlaces(tileID: tile.id, lang: language)
            + romePlaces(tileID: tile.id, lang: language)
        let tileCoord = EphemeralCoordinate(latitude: tile.centerLatitude, longitude: tile.centerLongitude)
        let nearby = all.filter { $0.coordinate.distanceMeters(to: tileCoord) <= 1_500 }
        return nearby.isEmpty ? hampiPlaces(tileID: tile.id, lang: language) : nearby
    }

    public static func hampiPlaces(tileID: String, lang: SaathiLanguage) -> [PlaceCandidate] {
        let summaryChariot: String
        let summaryPillars: String
        switch lang {
        case .hindi:
            summaryChariot = "हम्पी के विट्ठल मंदिर परिसर में स्थित पत्थर का रथ 16वीं शताब्दी में राजा कृष्णदेवराय के शासनकाल में बनाया गया था और यह गरुड़ को समर्पित है।"
            summaryPillars = "विट्ठल मंदिर का महामंडप अपने 56 संगीतमय स्तंभों के लिए प्रसिद्ध है जो ग्रेनाइट से तराशे गए हैं।"
        case .tamil:
            summaryPillars = "விட்டல கோயில் மகா மண்டபம் கிரானைட்டில் செதுக்கப்பட்ட 56 இசைத் தூண்களுக்காகப் புகழ்பெற்றது."
            summaryChariot = "ஹம்பி விட்டல கோயில் வளாகத்தில் உள்ள கல் தேர் 16-ஆம் நூற்றாண்டில் கிருஷ்ணதேவராயர் ஆட்சியில் கட்டப்பட்டது."
        case .urdu:
            summaryChariot = "ہمپی کے وٹل مندر کے احاطے میں واقع پتھر کا رتھ سولہویں صدی میں راجہ کرشن دیو رائے کے عہد میں تعمیر کیا گیا تھا۔"
            summaryPillars = "وٹل مندر کا مہا منڈپ اپنے 56 موسیقی والے گرینائٹ ستونوں کے لیے مشہور ہے۔"
        default:
            summaryChariot = "The iconic Stone Chariot inside Hampi's Vittala Temple complex was commissioned in the 16th century under Vijayanagara ruler Krishnadevaraya as a shrine to Garuda."
            summaryPillars = "The Maha Mantapa of Vittala Temple houses 56 carved granite musical pillars, known locally as SaReGaMa pillars, built in the 15th–16th centuries."
        }

        return [
            PlaceCandidate(
                id: "hampi_stone_chariot",
                title: "Stone Chariot, Vittala Temple",
                summary: summaryChariot,
                coordinate: EphemeralCoordinate(latitude: 15.3425, longitude: 76.4756),
                sitelinksCount: 42,
                tags: ["temple", "architecture", "vijayanagara"],
                citations: [
                    FactCitation(
                        provider: .wikipedia,
                        title: "Vittala Temple, Hampi",
                        urlString: "https://en.wikipedia.org/wiki/Vittala_Temple,_Hampi",
                        languageCode: lang.baseLanguageCode
                    ),
                    FactCitation(
                        provider: .openStreetMap,
                        title: "Vijaya Vittala Temple",
                        urlString: "https://www.openstreetmap.org",
                        languageCode: "en"
                    )
                ],
                tileID: tileID,
                sourceLanguageCode: lang.baseLanguageCode
            ),
            PlaceCandidate(
                id: "hampi_musical_pillars",
                title: "Musical Pillars Maha Mantapa",
                summary: summaryPillars,
                coordinate: EphemeralCoordinate(latitude: 15.3427, longitude: 76.4761),
                sitelinksCount: 31,
                tags: ["music", "temple", "granite"],
                citations: [
                    FactCitation(
                        provider: .wikipedia,
                        title: "Hampi",
                        urlString: "https://en.wikipedia.org/wiki/Hampi",
                        languageCode: lang.baseLanguageCode
                    )
                ],
                tileID: tileID,
                sourceLanguageCode: lang.baseLanguageCode
            )
        ]
    }

    public static func oldDelhiPlaces(tileID: String, lang: SaathiLanguage) -> [PlaceCandidate] {
        [
            PlaceCandidate(
                id: "delhi_red_fort",
                title: "Lal Qila (Red Fort) Lahori Gate",
                summary: "Commissioned by Emperor Shah Jahan in 1638 when he moved the Mughal capital to Shahjahanabad, the red sandstone walls rise over 30 meters above Chandni Chowk.",
                coordinate: EphemeralCoordinate(latitude: 28.6562, longitude: 77.2410),
                sitelinksCount: 95,
                tags: ["fort", "mughal", "architecture"],
                citations: [
                    FactCitation(
                        provider: .wikipedia,
                        title: "Red Fort",
                        urlString: "https://en.wikipedia.org/wiki/Red_Fort",
                        languageCode: "en"
                    )
                ],
                tileID: tileID,
                sourceLanguageCode: "en"
            ),
            PlaceCandidate(
                id: "delhi_chandni_chowk",
                title: "Chandni Chowk & Sis Ganj",
                summary: "Designed in 1650 by Jahanara Begum with a moonlight-reflecting canal down its center, Chandni Chowk connects the Red Fort to Fatehpuri Masjid.",
                coordinate: EphemeralCoordinate(latitude: 28.6557, longitude: 77.2323),
                sitelinksCount: 64,
                tags: ["market", "heritage", "mughal"],
                citations: [
                    FactCitation(
                        provider: .wikipedia,
                        title: "Chandni Chowk",
                        urlString: "https://en.wikipedia.org/wiki/Chandni_Chowk",
                        languageCode: "en"
                    )
                ],
                tileID: tileID,
                sourceLanguageCode: "en"
            )
        ]
    }

    public static func romePlaces(tileID: String, lang: SaathiLanguage) -> [PlaceCandidate] {
        [
            PlaceCandidate(
                id: "rome_colosseum",
                title: "Colosseum (Flavian Amphitheatre)",
                summary: "Completed in 80 CE under Emperor Titus, the Flavian Amphitheatre remains the largest ancient amphitheatre ever built, seating roughly 50,000 spectators.",
                coordinate: EphemeralCoordinate(latitude: 41.8902, longitude: 12.4922),
                sitelinksCount: 165,
                tags: ["amphitheatre", "roman", "architecture"],
                citations: [
                    FactCitation(
                        provider: .wikipedia,
                        title: "Colosseum",
                        urlString: "https://en.wikipedia.org/wiki/Colosseum",
                        languageCode: "en"
                    )
                ],
                tileID: tileID,
                sourceLanguageCode: "en"
            )
        ]
    }

    /// "Around you" places a few kilometres away, for the quiet stretches between landmarks.
    public static func areaPlaces(forTile tile: GeoTile, language: SaathiLanguage) -> [PlaceCandidate] {
        let tileCoord = EphemeralCoordinate(latitude: tile.centerLatitude, longitude: tile.centerLongitude)
        func place(_ id: String, _ title: String, _ summary: String, _ lat: Double, _ lon: Double,
                   _ sitelinks: Int, _ tags: [String], _ article: String) -> PlaceCandidate {
            PlaceCandidate(
                id: id,
                title: title,
                summary: summary,
                coordinate: EphemeralCoordinate(latitude: lat, longitude: lon),
                sitelinksCount: sitelinks,
                tags: tags,
                citations: [
                    FactCitation(
                        provider: .wikipedia,
                        title: article,
                        urlString: "https://en.wikipedia.org/wiki/\(article.replacingOccurrences(of: " ", with: "_"))",
                        languageCode: "en"
                    )
                ],
                tileID: tile.id,
                sourceLanguageCode: "en"
            )
        }
        let all = [
            place("hampi_virupaksha", "Virupaksha Temple",
                  "Virupaksha Temple, dedicated to Shiva, is the oldest functioning temple in Hampi; its 50-metre eastern gopuram towers over Hampi Bazaar.",
                  15.3350, 76.4600, 48, ["temple", "religion", "history"], "Virupaksha Temple, Hampi"),
            place("hampi_matanga_hill", "Matanga Hill",
                  "Matanga Hill is the highest point in Hampi's core, popular at sunrise for views over the boulder-strewn ruins of the Vijayanagara capital.",
                  15.3376, 76.4655, 12, ["ruins", "history"], "Hampi"),
            place("hampi_tungabhadra", "Tungabhadra River at Hampi",
                  "The Tungabhadra River bounds Hampi to the north; coracle ferries still cross it, and the ruins of an ancient stone bridge lie near Vittala Temple.",
                  15.3440, 76.4700, 30, ["history"], "Tungabhadra River"),
            place("delhi_jama_masjid", "Jama Masjid, Delhi",
                  "Built by Shah Jahan between 1644 and 1656, Jama Masjid is one of India's largest mosques, its courtyard holding up to 25,000 worshippers.",
                  28.6507, 77.2334, 70, ["religion", "architecture", "history"], "Jama Masjid, Delhi"),
            place("rome_palatine", "Palatine Hill",
                  "Palatine Hill, rising above the Forum, is where Rome's emperors built their palaces; the word 'palace' itself comes from its name.",
                  41.8892, 12.4875, 90, ["ruins", "history"], "Palatine Hill")
        ]
        return all.filter { $0.coordinate.distanceMeters(to: tileCoord) <= 6_000 }
    }

    public static func samplePersonalMemories() -> [PersonalMemoryItem] {
        [
            PersonalMemoryItem(
                id: "mem_photo_hampi_01",
                kind: .photo,
                title: "Sunrise at Vittala Stone Chariot",
                detail: "You photographed the carved granite wheels here in November 2024.",
                date: Date(timeIntervalSince1970: 1731567600),
                photoLocalIdentifier: "MOCK-PHASSET-HAMPI-001",
                approximateCoordinate: EphemeralCoordinate(latitude: 15.3425, longitude: 76.4756)
            ),
            PersonalMemoryItem(
                id: "mem_cal_01",
                kind: .calendarEvent,
                title: "Morning Heritage Walk",
                detail: "Scheduled 9:00 AM heritage architecture walk.",
                date: Date()
            )
        ]
    }
}
