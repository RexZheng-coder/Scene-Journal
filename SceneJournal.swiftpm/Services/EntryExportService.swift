import SwiftUI
import UIKit

struct EntryExportService {
    static func export(entry: JournalEntry) throws -> URL {
        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SceneJournalExports", isDirectory: true)
            .appendingPathComponent(entry.id.uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let baseName = sanitizedFileName(from: entry.title)
        let pdfURL = exportDirectory.appendingPathComponent("\(baseName)-summary.pdf")

        try writeSummaryPDF(entry: entry, to: pdfURL)

        return pdfURL
    }

    private static func writeSummaryPDF(entry: JournalEntry, to url: URL) throws {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let data = renderer.pdfData { context in
            context.beginPage()

            let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.label
            ]
            let sectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]

            var y: CGFloat = 56
            let horizontalInset: CGFloat = 44
            let maxWidth = bounds.width - horizontalInset * 2

            y = draw("Scene Journal", atY: y, width: maxWidth, x: horizontalInset, attributes: sectionAttrs)
            y += 8
            y = draw(entry.title, atY: y, width: maxWidth, x: horizontalInset, attributes: titleAttrs)
            y += 12

            if let image = firstExportImage(for: entry) {
                let imageHeight: CGFloat = 220
                let imageRect = CGRect(x: horizontalInset, y: y, width: maxWidth, height: imageHeight)
                image.draw(in: imageRect)
                y += imageHeight + 14
            }

            y = draw("Type: \(entry.type.displayName)", atY: y, width: maxWidth, x: horizontalInset, attributes: bodyAttrs)
            y = draw("Date: \(entry.date.formatted(date: .abbreviated, time: .omitted))", atY: y, width: maxWidth, x: horizontalInset, attributes: bodyAttrs)

            if !entry.venue.isEmpty {
                y = draw("Venue: \(entry.venue)", atY: y, width: maxWidth, x: horizontalInset, attributes: bodyAttrs)
            }
            if !entry.people.isEmpty {
                y = draw("People: \(entry.people)", atY: y, width: maxWidth, x: horizontalInset, attributes: bodyAttrs)
            }
            if !entry.tags.isEmpty {
                y = draw("Tags: \(entry.tags.joined(separator: ", "))", atY: y, width: maxWidth, x: horizontalInset, attributes: bodyAttrs)
            }

            let templateFields = entry.type.templateFields(detailA: entry.detailA, detailB: entry.detailB)
            if !templateFields.isEmpty || !entry.customFields.isEmpty {
                y += 12
                y = draw("Details", atY: y, width: maxWidth, x: horizontalInset, attributes: sectionAttrs)

                for field in templateFields + entry.customFields {
                    y = draw("• \(field.key): \(field.value)", atY: y, width: maxWidth, x: horizontalInset, attributes: bodyAttrs)
                }
            }

            let trimmedNotes = entry.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNotes.isEmpty {
                y += 12
                y = draw("Notes", atY: y, width: maxWidth, x: horizontalInset, attributes: sectionAttrs)
                let noteChunks = chunk(trimmedNotes, maxCharacters: 900)
                for (index, chunk) in noteChunks.enumerated() {
                    if y > bounds.height - 120 {
                        context.beginPage()
                        y = 56
                        y = draw("Notes (continued)", atY: y, width: maxWidth, x: horizontalInset, attributes: sectionAttrs)
                    } else if index > 0 {
                        y += 6
                    }
                    y = draw(chunk, atY: y, width: maxWidth, x: horizontalInset, attributes: bodyAttrs)
                }
            }
        }

        try data.write(to: url, options: .atomic)
    }

    private static func draw(
        _ text: String,
        atY y: CGFloat,
        width: CGFloat,
        x: CGFloat,
        attributes: [NSAttributedString.Key: Any]
    ) -> CGFloat {
        let textRect = CGRect(x: x, y: y, width: width, height: .greatestFiniteMagnitude)
        let nsText = NSString(string: text)
        let measured = nsText.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        nsText.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
        return y + ceil(measured.height) + 8
    }

    private static func sanitizedFileName(from text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let compact = text
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let raw = String(compact)
            .replacingOccurrences(of: "--", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return raw.isEmpty ? "entry" : raw
    }

    private static func firstExportImage(for entry: JournalEntry) -> UIImage? {
        if let data = entry.photos.first?.data, let image = UIImage(data: data) {
            return image
        }

        if let remoteString = entry.photos.first?.remoteURL,
           let remoteURL = URL(string: remoteString),
           let data = try? Data(contentsOf: remoteURL),
           let image = UIImage(data: data) {
            return image
        }

        return nil
    }

    private static func chunk(_ text: String, maxCharacters: Int) -> [String] {
        guard text.count > maxCharacters else { return [text] }
        var result: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            let candidate = current.isEmpty ? String(word) : "\(current) \(word)"
            if candidate.count > maxCharacters, !current.isEmpty {
                result.append(current)
                current = String(word)
            } else {
                current = candidate
            }
        }
        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
}
