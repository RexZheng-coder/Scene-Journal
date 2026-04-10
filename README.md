# SceneJournal

SceneJournal is a Swift Playgrounds app built for the Apple Swift Student Challenge. It helps users capture memorable live experiences such as concerts, Broadway shows, and other special events, then turn those moments into a personal journal they can revisit later.

## What This Project Does

SceneJournal is designed as a memory journal for real-world experiences. Instead of keeping event memories scattered across photos, notes, and ticket screenshots, the app brings them together into one place.

With SceneJournal, a user can:

- create journal entries for concerts, Broadway shows, and custom event types
- save titles, venues, people, notes, tags, and event-specific details
- attach photos to each memory
- browse entries by category, search terms, and advanced filters
- view memories on a map
- generate smart highlights and keywords from notes
- export an entry as a shareable PDF summary

The app ships with sample content so the experience is easy to explore right away.

## Why I Built It

Live experiences often disappear into camera rolls and short notes after the moment passes. SceneJournal focuses on helping people preserve the feeling and context of those memories, not just the fact that they happened.

The project combines journaling, lightweight organization, and playful reflection into a format that feels personal and easy to use on iPhone and iPad.

## Features

- category-based journaling with built-in templates for General, Concert, and Broadway entries
- support for custom categories
- onboarding flow for first-time users
- local persistence using `UserDefaults`
- search and advanced filtering
- map-based memory browsing
- smart highlight generation with Apple Intelligence when available, plus an on-device fallback
- PDF export for sharing or saving summaries

## How To Use

1. Open the project

Open [SceneJournal.swiftpm](/Users/rexzheng/Columbia/Apple-swift-challenge/SceneJournal.swiftpm) in Swift Playgrounds or Xcode.

This project is structured as a Swift Playgrounds app package, so the main app lives inside that folder.

2. Run the app

- In Swift Playgrounds: open the package and tap Run.
- In Xcode: open the package folder and run it on an iPhone or iPad simulator.

The minimum deployment target in the package is iOS 16.0.

3. Explore the experience

- complete the onboarding flow
- browse the sample entries already included in the app
- create a new memory with the `+` button
- add photos, venue details, tags, and notes
- open the map view to see saved places
- export an entry from its detail view as a PDF summary

## Project Structure

- [SceneJournal.swiftpm](/Users/rexzheng/Columbia/Apple-swift-challenge/SceneJournal.swiftpm): main Swift Playgrounds app
- [docs/screenshots](/Users/rexzheng/Columbia/Apple-swift-challenge/docs/screenshots): screenshots used for presentation and documentation

## Screenshots

Challenge presentation images are stored in [docs/screenshots](/Users/rexzheng/Columbia/Apple-swift-challenge/docs/screenshots).

## Git Notes

This repository is organized around the `SceneJournal.swiftpm` app. Build artifacts and generated workspace data are excluded so the repo stays clean and easier to maintain.
