import Foundation

/// SF Symbol names, centralised. The pen places vuesax/Iconsax icons; D-IC1 maps each to the
/// nearest SF Symbol (zero bundled assets, weight-matched to text). The vuesax name is noted
/// beside each entry.
public enum Icons {
    // MARK: Tabs (active = filled, inactive = outline)
    public static let calendar = "calendar"                    // calendar
    public static let checkIn = "checkmark.square.fill"        // task-square (bold)
    public static let checkInOutline = "checkmark.square"      // task-square (linear)
    public static let insights = "chart.bar.fill"              // chart (bold)
    public static let insightsOutline = "chart.bar"            // chart (outline)
    public static let settings = "gearshape.fill"              // setting-2 (bold)
    public static let settingsOutline = "gearshape"            // setting-2 (twotone)

    // MARK: Chrome
    public static let back = "chevron.left"                    // arrow-left
    public static let more = "ellipsis"                        // more
    public static let chevronUp = "chevron.up"                 // arrow-up
    public static let chevronDown = "chevron.down"
    public static let chevronRight = "chevron.right"           // arrow-right
    public static let add = "plus"                             // add
    public static let check = "checkmark"
    public static let close = "xmark"

    // MARK: Actions
    public static let mic = "mic.fill"                         // microphone-2
    public static let note = "square.and.pencil"               // edit-2
    public static let stop = "stop.fill"                       // stop
    public static let play = "play.fill"
    public static let pause = "pause.fill"
    public static let trash = "trash"

    // MARK: Domain
    public static let medication = "pills.fill"                // hub "Log Medications"
    public static let capsule = "pill"                         // capsule (line style)
    public static let sideEffect = "bandage.fill"
    public static let lock = "lock.fill"                       // lock
    public static let unlock = "lock.open.fill"                // unlock
    public static let sparkle = "sparkles"                     // AI byline
    public static let record = "record.circle"                 // record-circle
    public static let info = "info.circle.fill"                // info-circle
    public static let voice = "waveform.circle"                // voice-circle
    public static let accessibility = "accessibility"          // accessibility figure
    public static let clock = "clock"                          // time field
    public static let cellular = "antenna.radiowaves.left.and.right"
    public static let waveform = "waveform"                    // voice model row
    public static let brain = "brain.head.profile"             // insights model row
    public static let shield = "shield"                        // dose guard
    public static let export = "lock.doc"                      // journal export
    public static let privacy = "hand.raised"                  // privacy policy
    public static let credits = "heart"                        // acknowledgements
    public static let warning = "exclamationmark.triangle"     // ephemeral store
    public static let copy = "doc.on.doc"                      // recovery key
    public static let arrowRight = "arrow.right"               // onboarding continue
    public static let lockShield = "lock.shield"               // download permission
    public static let feedback = "exclamationmark.bubble"      // debug feedback button
    public static let shortcuts = "arrow.up.forward.app"       // sticker walkthrough hand-off
    public static let done = "checkmark.circle.fill"           // sticker walkthrough "Done"
}
