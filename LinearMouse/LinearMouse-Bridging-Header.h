//
//  Touch-Bridging-Header.h
//  LinearMouse
//
//  Created by lujjjh on 2021/8/5.
//

#include <CoreGraphics/CoreGraphics.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>

#include "Utilities/Process.h"

CF_IMPLICIT_BRIDGING_ENABLED

enum {
    kIOHIDEventTypeNULL,
    kIOHIDEventTypeVendorDefined,
    kIOHIDEventTypeKeyboard = 3,
    kIOHIDEventTypeRotation = 5,
    kIOHIDEventTypeScroll = 6,
    kIOHIDEventTypeZoom = 8,
    kIOHIDEventTypeDigitizer = 11,
    kIOHIDEventTypeNavigationSwipe = 16,
    kIOHIDEventTypeForce = 32,
};
typedef uint32_t IOHIDEventType;
typedef CFTypeRef IOHIDEventRef;
typedef double IOHIDFloat;
typedef uint32_t IOHIDEventField;

#define IOHIDEventFieldBase(type) (type << 16)

#define kIOHIDEventFieldScrollBase IOHIDEventFieldBase(kIOHIDEventTypeScroll)
static const IOHIDEventField kIOHIDEventFieldScrollX = (kIOHIDEventFieldScrollBase | 0);
static const IOHIDEventField kIOHIDEventFieldScrollY = (kIOHIDEventFieldScrollBase | 1);

// Digitizer (Trackpad) field definitions
#define kIOHIDEventFieldDigitizerBase IOHIDEventFieldBase(kIOHIDEventTypeDigitizer)
static const IOHIDEventField kIOHIDEventFieldDigitizerX = (kIOHIDEventFieldDigitizerBase | 0);
static const IOHIDEventField kIOHIDEventFieldDigitizerY = (kIOHIDEventFieldDigitizerBase | 1);
static const IOHIDEventField kIOHIDEventFieldDigitizerRange = (kIOHIDEventFieldDigitizerBase | 5);
static const IOHIDEventField kIOHIDEventFieldDigitizerTouch = (kIOHIDEventFieldDigitizerBase | 6);
static const IOHIDEventField kIOHIDEventFieldDigitizerPressure = (kIOHIDEventFieldDigitizerBase | 11);

// Swipe field definitions
#define kIOHIDEventFieldSwipeBase IOHIDEventFieldBase(kIOHIDEventTypeNavigationSwipe)
static const IOHIDEventField kIOHIDEventFieldSwipeMask = (kIOHIDEventFieldSwipeBase | 0);

IOHIDEventRef CGEventCopyIOHIDEvent(CGEventRef);
IOHIDEventType IOHIDEventGetType(IOHIDEventRef);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef, IOHIDEventField);
void IOHIDEventSetFloatValue(IOHIDEventRef, IOHIDEventField, IOHIDFloat);
int64_t IOHIDEventGetIntegerValue(IOHIDEventRef, IOHIDEventField);
void IOHIDEventSetIntegerValue(IOHIDEventRef, IOHIDEventField, int64_t);
IOHIDEventRef IOHIDEventGetEvent(IOHIDEventRef, IOHIDEventType);
CFArrayRef IOHIDEventGetChildren(IOHIDEventRef);

CF_IMPLICIT_BRIDGING_DISABLED
