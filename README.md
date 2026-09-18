# AI Customer Support — iOS/macOS Client

A native SwiftUI client for the [AI Customer Support Assistant](https://github.com/gauravkumar-bug/ai-customer-support) — a RAG-powered customer support backend built with FastAPI, ChromaDB, and a locally hosted LLM via Ollama.

## Features

- Email/password authentication with JWT, plus Google Sign-In
- Real-time chat with the AI support assistant (order tracking, FAQs, cancellations)
- Order details view with live status and delivery info
- Change password / forgot password (with email OTP) flows
- Local chat history persistence
- Native SwiftUI, works on both iOS and macOS

## Tech Stack

SwiftUI, Combine, URLSession (async/await), Keychain for secure token storage, GoogleSignIn SDK

## Setup

1. Clone the backend first and get it running: [ai-customer-support](https://github.com/gauravkumar-bug/ai-customer-support)
2. Open `AI Customer Support.xcworkspace` in Xcode
3. Make sure the backend is running at `http://127.0.0.1:8000` (or update `APIService.swift`'s `baseURL` if it's hosted elsewhere)
4. Build and run (`Cmd+R`)

### Google Sign-In (optional)

If you want Google Sign-In to work, you'll need to:
1. Add the `GoogleSignIn-iOS` package via Swift Package Manager
2. Add your OAuth Client ID's URL scheme to the app's `Info.plist` → URL Types
3. Set `GOOGLE_CLIENT_ID` on the backend

Without this setup, the app still works fine with email/password login.

## Screenshots

_Coming soon._

## Related

- [Backend repo](https://github.com/gauravkumar-bug/ai-customer-support) — FastAPI + RAG + Ollama
