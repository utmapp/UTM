//
// Copyright © 2024 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI

// MARK: - Core Data Models
struct MarkdownElement {
    let type: MarkdownElementType
    let content: String
    let number: Int?
    let id = UUID()
    
    init(type: MarkdownElementType, content: String, number: Int? = nil) {
        self.type = type
        self.content = content
        self.number = number
    }
}

enum MarkdownElementType {
    case heading1, heading2, heading3
    case paragraph
    case listItem, numberedListItem
    case codeBlock
    case divider
    case table
    case link
}

// MARK: - Parser
class MarkdownParser {
    static func parse(_ content: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = content.components(separatedBy: .newlines)
        var currentParagraph = ""
        var inCodeBlock = false
        var codeBlockContent = ""
        var lineIndex = 0
        
        while lineIndex < lines.count {
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Handle code blocks
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    if !codeBlockContent.isEmpty {
                        elements.append(MarkdownElement(type: .codeBlock, content: codeBlockContent.trimmingCharacters(in: .whitespacesAndNewlines)))
                        codeBlockContent = ""
                    }
                    inCodeBlock = false
                } else {
                    // Start code block
                    if !currentParagraph.isEmpty {
                        elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                        currentParagraph = ""
                    }
                    inCodeBlock = true
                }
                lineIndex += 1
                continue
            }
            
            if inCodeBlock {
                codeBlockContent += line + "\n"
                lineIndex += 1
                continue
            }
            
            // Handle headings
            if trimmed.hasPrefix("# ") {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentParagraph = ""
                }
                elements.append(MarkdownElement(type: .heading1, content: String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("## ") {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentParagraph = ""
                }
                elements.append(MarkdownElement(type: .heading2, content: String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentParagraph = ""
                }
                elements.append(MarkdownElement(type: .heading3, content: String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                // Handle list items
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentParagraph = ""
                }
                elements.append(MarkdownElement(type: .listItem, content: String(trimmed.dropFirst(2))))
            } else if let match = trimmed.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
                // Handle numbered lists
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentParagraph = ""
                }
                let numberStr = String(trimmed[..<match.upperBound]).trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
                let content = String(trimmed[match.upperBound...])
                elements.append(MarkdownElement(type: .numberedListItem, content: content, number: Int(numberStr)))
            } else if trimmed.contains("|") && !trimmed.isEmpty && !trimmed.contains("---") {
                // Handle table rows - Fixed to prevent multiple tables for single markdown table
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentParagraph = ""
                }
                
                // Collect all consecutive table rows
                var tableContent = ""
                var tableLineIndex = lineIndex
                
                while tableLineIndex < lines.count {
                    let tableLine = lines[tableLineIndex].trimmingCharacters(in: .whitespaces)
                    if tableLine.contains("|") && !tableLine.isEmpty {
                        if !tableLine.contains("---") { // Skip separator lines
                            tableContent += tableLine + "\n"
                        }
                        tableLineIndex += 1
                    } else if tableLine.isEmpty && tableLineIndex > lineIndex {
                        // Allow one empty line within table, but continue
                        tableLineIndex += 1
                        if tableLineIndex < lines.count {
                            let nextLine = lines[tableLineIndex].trimmingCharacters(in: .whitespaces)
                            if !nextLine.contains("|") {
                                break // End of table
                            }
                        }
                    } else {
                        break
                    }
                }
                
                if !tableContent.isEmpty {
                    elements.append(MarkdownElement(type: .table, content: tableContent))
                }
                
                lineIndex = tableLineIndex - 1
                
            } else if trimmed == "---" || trimmed == "***" {
                // Handle dividers
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentParagraph = ""
                }
                elements.append(MarkdownElement(type: .divider, content: ""))
            } else if trimmed.isEmpty {
                // Empty line - end current paragraph
                if !currentParagraph.isEmpty {
                    elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentParagraph = ""
                }
            } else {
                // Regular text - add to current paragraph
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmed
            }
            
            lineIndex += 1
        }
        
        // Handle any remaining content
        if inCodeBlock && !codeBlockContent.isEmpty {
            elements.append(MarkdownElement(type: .codeBlock, content: codeBlockContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        } else if !currentParagraph.isEmpty {
            elements.append(MarkdownElement(type: .paragraph, content: currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        return elements
    }
    
    static func parsePreview(_ content: String, maxLength: Int) -> [MarkdownElement] {
        let previewContent = String(content.prefix(maxLength)) + (content.count > maxLength ? "..." : "")
        return parse(previewContent)
    }
    
    static func extractLinkReferences(from content: String) -> [String: String] {
        var references: [String: String] = [:]
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let match = trimmed.range(of: #"^\[([^\]]+)\]:\s*(.+)$"#, options: .regularExpression) {
                let linkPattern = String(trimmed[match])
                let parts = linkPattern.components(separatedBy: "]: ")
                if parts.count == 2 {
                    let key = String(parts[0].dropFirst()) // Remove [
                    let url = parts[1]
                    references[key] = url
                }
            }
        }
        
        return references
    }
}

struct TextComponent {
    let text: String
    let isLink: Bool
    let url: URL?
    let id = UUID()
}

// MARK: - Link Text Processor
class LinkTextProcessor {
    static func processReferenceLinks(_ text: String, linkReferences: [String: String]) -> String {
        var processed = text
        
        // Handle reference links like [text][ref]
        let referencePattern = #"\[([^\]]+)\]\[([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: referencePattern) {
            let range = NSRange(processed.startIndex..<processed.endIndex, in: processed)
            let matches = regex.matches(in: processed, range: range).reversed()
            
            for match in matches {
                if match.numberOfRanges >= 3,
                   let textRange = Range(match.range(at: 1), in: processed),
                   let refRange = Range(match.range(at: 2), in: processed) {
                    
                    let linkText = String(processed[textRange])
                    let refKey = String(processed[refRange])
                    
                    if let url = linkReferences[refKey] {
                        let replacement = "[\(linkText)](\(url))"
                        if let fullRange = Range(match.range, in: processed) {
                            processed.replaceSubrange(fullRange, with: replacement)
                        }
                    }
                }
            }
        }
        
        return processed
    }
    
    static func parseTextWithLinks(_ text: String, linkReferences: [String: String]) -> [TextComponent] {
        var components: [TextComponent] = []
        let processed = processReferenceLinks(text, linkReferences: linkReferences)
        
        // Simple link parsing for fallback
        let linkPattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        if let regex = try? NSRegularExpression(pattern: linkPattern) {
            let range = NSRange(processed.startIndex..<processed.endIndex, in: processed)
            let matches = regex.matches(in: processed, range: range)
            
            var lastEnd = processed.startIndex
            
            for match in matches {
                // Add text before link
                if let matchRange = Range(match.range, in: processed) {
                    let beforeText = String(processed[lastEnd..<matchRange.lowerBound])
                    if !beforeText.isEmpty {
                        components.append(TextComponent(text: beforeText, isLink: false, url: nil))
                    }
                    
                    // Add link
                    if match.numberOfRanges >= 3,
                       let textRange = Range(match.range(at: 1), in: processed),
                       let urlRange = Range(match.range(at: 2), in: processed) {
                        
                        let linkText = String(processed[textRange])
                        let urlString = String(processed[urlRange])
                        let url = URL(string: urlString)
                        
                        components.append(TextComponent(text: linkText, isLink: true, url: url))
                    }
                    
                    lastEnd = matchRange.upperBound
                }
            }
            
            // Add remaining text
            if lastEnd < processed.endIndex {
                let remainingText = String(processed[lastEnd...])
                if !remainingText.isEmpty {
                    components.append(TextComponent(text: remainingText, isLink: false, url: nil))
                }
            }
        } else {
            components.append(TextComponent(text: processed, isLink: false, url: nil))
        }
        
        return components.isEmpty ? [TextComponent(text: processed, isLink: false, url: nil)] : components
    }
}

// MARK: - Full-Featured Markdown Renderer
struct MarkdownRenderer: View {
    let content: String
    let linkReferences: [String: String]
    
    init(content: String, linkReferences: [String: String] = [:]) {
        self.content = content
        self.linkReferences = linkReferences.isEmpty ? MarkdownParser.extractLinkReferences(from: content) : linkReferences
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MarkdownParser.parse(content), id: \.id) { element in
                switch element.type {
                case .heading1:
                    if #available(macOS 12, *) {
                        Text(element.content)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 8)
                            .textSelection(.enabled)
                    } else {
                        Text(element.content)
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.top, 8)
                    }
                        
                case .heading2:
                    if #available(macOS 12, *) {
                        Text(element.content)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top, 6)
                            .textSelection(.enabled)
                    } else {
                        Text(element.content)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top, 6)
                    }
                        
                case .heading3:
                    if #available(macOS 12, *) {
                        Text(element.content)
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding(.top, 4)
                            .textSelection(.enabled)
                    } else {
                        Text(element.content)
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding(.top, 4)
                    }
                        
                case .listItem:
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.top, 2)
                        
                        MarkdownFormattedText(content: element.content, linkReferences: linkReferences)
                        
                        Spacer()
                    }
                    .padding(.leading, 8)
                    
                case .numberedListItem:
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(element.number ?? 1).")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .padding(.top, 2)
                        
                        MarkdownFormattedText(content: element.content, linkReferences: linkReferences)
                        
                        Spacer()
                    }
                    .padding(.leading, 8)
                    
                case .codeBlock:
                    if #available(macOS 12, *) {
                        Text(element.content)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    } else {
                        Text(element.content)
                            .font(.system(.body, design: .monospaced))
                            .padding(12)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                    }
                        
                case .paragraph:
                    MarkdownFormattedText(content: element.content, linkReferences: linkReferences)
                    
                case .table:
                    MarkdownTable(content: element.content)
                    
                case .divider:
                    Divider()
                        .padding(.vertical, 4)
                        
                case .link:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview Markdown Renderer with Length Limits
struct MarkdownPreview: View {
    let content: String
    let maxLength: Int
    
    var body: some View {
        let elements = MarkdownParser.parsePreview(content, maxLength: maxLength)
        
        VStack(alignment: .leading, spacing: 8) {
            ForEach(elements, id: \.id) { element in
                switch element.type {
                case .heading2:
                    Text(element.content)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                        
                case .heading3:
                    Text(element.content)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.top, 2)
                        
                case .listItem:
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(.top, 2)
                        
                        if #available(macOS 12, *), let attributed = try? AttributedString(markdown: element.content) {
                            Text(attributed)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(element.content)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 6)
                    
                case .numberedListItem:
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(element.number ?? 1).")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                            .padding(.top, 1)
                        
                        if #available(macOS 12, *), let attributed = try? AttributedString(markdown: element.content) {
                            Text(attributed)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(element.content)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 6)
                    
                case .paragraph:
                    if #available(macOS 12, *), let attributed = try? AttributedString(markdown: element.content) {
                        Text(attributed)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(element.content)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                default:
                    EmptyView()
                }
            }
        }
        .lineLimit(5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Text-Only Renderer
struct MarkdownText: View {
    let content: String
    let linkReferences: [String: String]
    
    var body: some View {
        if #available(macOS 12, *) {
            let processedContent = LinkTextProcessor.processReferenceLinks(content, linkReferences: linkReferences)
            
            if let attributedString = try? AttributedString(markdown: processedContent) {
                Text(attributedString)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(processedContent)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            // Fallback for older macOS versions
            Text(content)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Formatted Text Renderer
struct MarkdownFormattedText: View {
    let content: String
    let linkReferences: [String: String]
    
    var body: some View {
        if #available(macOS 12, *) {
            // Use AttributedString for full markdown formatting, then add custom link handling
            let processedContent = LinkTextProcessor.processReferenceLinks(content, linkReferences: linkReferences)
            
            if let attributedString = try? AttributedString(markdown: processedContent) {
                // Check if the text contains links that need custom cursor behavior
                if processedContent.contains("[") && processedContent.contains("](") {
                    // Text has links - use custom rendering for proper cursor behavior
                    MarkdownTextWithCustomLinks(content: processedContent, linkReferences: linkReferences)
                } else {
                    // No links - use simple AttributedString rendering
                    Text(attributedString)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                // Fallback to simple text rendering
                MarkdownText(content: content, linkReferences: linkReferences)
            }
        } else {
            // Fallback for older macOS versions
            MarkdownText(content: content, linkReferences: linkReferences)
        }
    }
}

// MARK: - Custom Link Handling for macOS 12+
@available(macOS 12, *)
struct MarkdownTextWithCustomLinks: View {
    let content: String
    let linkReferences: [String: String]

    var body: some View {
        // Parse the text into components (plain and links)
        let components = LinkTextProcessor.parseTextWithLinks(content, linkReferences: linkReferences)
        HStack(spacing: 0) {
            ForEach(components, id: \.id) { component in
                if component.isLink, let url = component.url {
                    StyledLink(text: component.text, url: url)
                } else {
                    Text(component.text)
                }
            }
        }
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Styled Link Component
private struct StyledLink: View {
    let text: String
    let url: URL
    
    var body: some View {
        if #available(macOS 13, *) {
            Link(text, destination: url)
                .underline(true, color: .blue)
                .foregroundColor(.blue)
        } else {
            Link(text, destination: url)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Table Renderer
struct MarkdownTable: View {
    let content: String
    
    var body: some View {
        let rows = parseTable(content)
        
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, cell in
                            if #available(macOS 13, *) {
                                Text(cell.trimmingCharacters(in: .whitespaces))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(index == 0 ? Color.secondary.opacity(0.1) : Color.clear)
                                    .fontWeight(index == 0 ? .semibold : .regular)
                            } else {
                                Text(cell.trimmingCharacters(in: .whitespaces))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(index == 0 ? Color.secondary.opacity(0.1) : Color.clear)
                                    .font(index == 0 ? .body.weight(.semibold) : .body)
                            }
                            
                            if cellIndex < row.count - 1 {
                                Divider()
                            }
                        }
                    }
                    
                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
            .overlay(
                Rectangle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(4)
        }
    }
    
    private func parseTable(_ content: String) -> [[String]] {
        let lines = content.components(separatedBy: .newlines)
        var rows: [[String]] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("|") && !trimmed.isEmpty {
                // Skip separator lines (like |---|---|)
                if trimmed.contains("---") {
                    continue
                }
                
                let cells = trimmed.components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                if !cells.isEmpty {
                    rows.append(cells)
                }
            }
        }
        
        return rows
    }
}
