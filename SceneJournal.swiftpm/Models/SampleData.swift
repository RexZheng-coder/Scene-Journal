import Foundation

enum SampleData {
    static var entries: [JournalEntry] {
        let calendar = Calendar.current
        let now = Date()

        func daysAgo(_ day: Int) -> Date {
            calendar.date(byAdding: .day, value: -day, to: now) ?? now
        }

        return [
            JournalEntry(
                type: .concert,
                title: "Coldplay: Music of the Spheres",
                venue: "MetLife Stadium",
                people: "Coldplay",
                detailA: "Viva La Vida",
                detailB: "Great crowd sing-along during encore",
                notes: "The stadium lights and wristbands were synchronized perfectly. Sky Full of Stars felt magical.",
                date: daysAgo(14),
                photos: samplePhotos(["concert1.jpg", "concert2.jpg"]),
                tags: ["stadium", "live", "night"],
                customFields: [
                    EntryField(key: "City", value: "East Rutherford"),
                    EntryField(key: "Weather", value: "Warm and clear")
                ]
            ),
            JournalEntry(
                type: .broadway,
                title: "Hadestown",
                venue: "Walter Kerr Theatre",
                people: "Jordan Fisher, Solea Pfeiffer",
                detailA: "Wait For Me",
                detailB: "Orchestra Left, Row H",
                notes: "The staging and lighting design were incredible. The transitions felt seamless.",
                date: daysAgo(35),
                photos: samplePhotos(["broadway1.jpg"]),
                tags: ["broadway", "musical", "favorite"],
                customFields: [
                    EntryField(key: "Ticket", value: "$129"),
                    EntryField(key: "Intermission Snack", value: "Chocolate cookie")
                ]
            ),
            JournalEntry(
                type: .general,
                title: "Jazz Night at Blue Note",
                venue: "Blue Note Jazz Club",
                people: "Local Quartet",
                detailA: "Improvised piano solo",
                detailB: "Late-night vibe",
                notes: "A cozy and intimate venue. The final saxophone solo was unforgettable.",
                date: daysAgo(8),
                photos: samplePhotos(["jazz1.jpg"]),
                tags: ["jazz", "club", "intimate"],
                customFields: [
                    EntryField(key: "Companion", value: "Alex"),
                    EntryField(key: "Set Count", value: "2")
                ]
            ),
            JournalEntry(
                type: .general,
                title: "Campus Spring Festival",
                venue: "College Walk",
                people: "Student Bands",
                detailA: "Sunset acoustic set",
                detailB: "Food trucks and outdoor booths",
                notes: "A relaxed afternoon with live music, good food, and friends.",
                date: daysAgo(21),
                photos: samplePhotos(["concert1.jpg"]),
                tags: ["festival", "campus", "friends"],
                customFields: [
                    EntryField(key: "Best Food", value: "Korean tacos")
                ]
            ),
            JournalEntry(
                type: .broadway,
                title: "Hamilton",
                venue: "Richard Rodgers Theatre",
                people: "Broadway Cast",
                detailA: "Yorktown",
                detailB: "Center Orchestra, Row K",
                notes: "The choreography was sharp and energetic. Non-Stop was a highlight.",
                date: daysAgo(60),
                photos: samplePhotos(["theatre1.jpg"]),
                tags: ["history", "rap", "must-watch"],
                customFields: [
                    EntryField(key: "Runtime", value: "2h 45m")
                ]
            )
        ]
    }

    private static func samplePhotos(_ names: [String]) -> [EntryPhoto] {
        names.compactMap { name in
            let fileName = (name as NSString).deletingPathExtension
            let fileExtension = (name as NSString).pathExtension
            guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension.isEmpty ? nil : fileExtension),
                  let data = try? Data(contentsOf: url) else {
                return nil
            }
            return EntryPhoto(data: data)
        }
    }
}
