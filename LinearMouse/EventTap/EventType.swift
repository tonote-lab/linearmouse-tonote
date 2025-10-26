// MIT License
// Copyright (c) 2021-2025 LinearMouse

class EventType {
    static let all: [CGEventType] = [
        .scrollWheel,
        .leftMouseDown,
        .leftMouseUp,
        .leftMouseDragged,
        .rightMouseDown,
        .rightMouseUp,
        .rightMouseDragged,
        .otherMouseDown,
        .otherMouseUp,
        .otherMouseDragged,
        .keyDown,
        .keyUp,
        .flagsChanged,
        .init(rawValue: 29)! // gesture events (NSEvent.EventType.gesture)
    ]

    static let mouseMoved: CGEventType = .mouseMoved
}
