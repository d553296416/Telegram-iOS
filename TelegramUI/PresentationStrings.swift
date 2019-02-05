import Foundation

private let fallbackDict: [String: String] = {
    guard let mainPath = Bundle.main.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: mainPath) else {
        return [:]
    }
    guard let path = bundle.path(forResource: "Localizable", ofType: "strings") else {
        return [:]
    }
    guard let dict = NSDictionary(contentsOf: URL(fileURLWithPath: path)) as? [String: String] else {
        return [:]
    }
    return dict
}()

private extension PluralizationForm {
    var canonicalSuffix: String {
        switch self {
            case .zero:
                return "_0"
            case .one:
                return "_1"
            case .two:
                return "_2"
            case .few:
                return "_3_10"
            case .many:
                return "_many"
            case .other:
                return "_any"
        }
    }
}

public final class PresentationStringsComponent {
    public let languageCode: String
    public let localizedName: String
    public let pluralizationRulesCode: String?
    public let dict: [String: String]
    
    public init(languageCode: String, localizedName: String, pluralizationRulesCode: String?, dict: [String: String]) {
        self.languageCode = languageCode
        self.localizedName = localizedName
        self.pluralizationRulesCode = pluralizationRulesCode
        self.dict = dict
    }
}
        
private func getValue(_ primaryComponent: PresentationStringsComponent, _ secondaryComponent: PresentationStringsComponent?, _ key: String) -> String {
    if let value = primaryComponent.dict[key] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[key] {
        return value
    } else if let value = fallbackDict[key] {
        return value
    } else {
        return key
    }
}

private func getValueWithForm(_ primaryComponent: PresentationStringsComponent, _ secondaryComponent: PresentationStringsComponent?, _ key: String, _ form: PluralizationForm) -> String {
    let builtKey = key + form.canonicalSuffix
    if let value = primaryComponent.dict[builtKey] {
        return value
    } else if let secondaryComponent = secondaryComponent, let value = secondaryComponent.dict[builtKey] {
        return value
    } else if let value = fallbackDict[builtKey] {
        return value
    }
    return key
}
        
private let argumentRegex = try! NSRegularExpression(pattern: "%(((\\d+)\\$)?)([@df])", options: [])
private func extractArgumentRanges(_ value: String) -> [(Int, NSRange)] {
    var result: [(Int, NSRange)] = []
    let string = value as NSString
    let matches = argumentRegex.matches(in: string as String, options: [], range: NSRange(location: 0, length: string.length))
    var index = 0
    for match in matches {
        var currentIndex = index
        if match.range(at: 3).location != NSNotFound {
            currentIndex = Int(string.substring(with: match.range(at: 3)))! - 1
        }
        result.append((currentIndex, match.range(at: 0)))
        index += 1
    }
    result.sort(by: { $0.1.location < $1.1.location })
    return result
}
    
func formatWithArgumentRanges(_ value: String, _ ranges: [(Int, NSRange)], _ arguments: [String]) -> (String, [(Int, NSRange)]) {
    let string = value as NSString
    
    var resultingRanges: [(Int, NSRange)] = []

    var currentLocation = 0

    let result = NSMutableString()
    for (index, range) in ranges {
        if currentLocation < range.location {
            result.append(string.substring(with: NSRange(location: currentLocation, length: range.location - currentLocation)))
        }
        resultingRanges.append((index, NSRange(location: result.length, length: (arguments[index] as NSString).length)))
        result.append(arguments[index])
        currentLocation = range.location + range.length
    }
    if currentLocation != string.length {
        result.append(string.substring(with: NSRange(location: currentLocation, length: string.length - currentLocation)))
    }
    return (result as String, resultingRanges)
}
        
private final class DataReader {
    private let data: Data
    private var ptr: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    func readInt32() -> Int32 {
        assert(self.ptr + 4 <= self.data.count)
        let result = self.data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) -> Int32 in
            var value: Int32 = 0
            memcpy(&value, bytes.advanced(by: self.ptr), 4)
            return value
        }
        self.ptr += 4
        return result
    }

    func readString() -> String {
        let length = Int(self.readInt32())
        assert(self.ptr + length <= self.data.count)
        let value = String(data: self.data.subdata(in: self.ptr ..< self.ptr + length), encoding: .utf8)!
        self.ptr += length
        return value
    }
}
        
private func loadMapping() -> ([Int], [String], [Int], [Int], [String]) {
    guard let filePath = frameworkBundle.path(forResource: "PresentationStrings", ofType: "mapping") else {
        fatalError()
    }
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
        fatalError()
    }

    let reader = DataReader(data)

    let idCount = Int(reader.readInt32())
    var sIdList: [Int] = []
    var sKeyList: [String] = []
    var sArgIdList: [Int] = []
    for _ in 0 ..< idCount {
        let id = Int(reader.readInt32())
        sIdList.append(id)
        sKeyList.append(reader.readString())
        if reader.readInt32() != 0 {
            sArgIdList.append(id)
        }
    }

    let pCount = Int(reader.readInt32())
    var pIdList: [Int] = []
    var pKeyList: [String] = []
    for _ in 0 ..< Int(pCount) {
        pIdList.append(Int(reader.readInt32()))
        pKeyList.append(reader.readString())
    }

    return (sIdList, sKeyList, sArgIdList, pIdList, pKeyList)
}

private let keyMapping: ([Int], [String], [Int], [Int], [String]) = loadMapping()
        
public final class PresentationStrings {
    public let lc: UInt32
    
    public let primaryComponent: PresentationStringsComponent
    public let secondaryComponent: PresentationStringsComponent?
    public let baseLanguageCode: String
        
    private let _s: [Int: String]
    private let _r: [Int: [(Int, NSRange)]]
    private let _ps: [Int: String]
    public var CallFeedback_ReasonSilentLocal: String { return self._s[0]! }
    public var StickerPack_ShowStickers: String { return self._s[1]! }
    public var Map_PullUpForPlaces: String { return self._s[2]! }
    public var Channel_Status: String { return self._s[4]! }
    public var TwoStepAuth_ChangePassword: String { return self._s[5]! }
    public var Map_LiveLocationFor1Hour: String { return self._s[6]! }
    public var CheckoutInfo_ShippingInfoAddress2Placeholder: String { return self._s[7]! }
    public var Settings_AppleWatch: String { return self._s[8]! }
    public var Login_InvalidCountryCode: String { return self._s[9]! }
    public var WebSearch_RecentSectionTitle: String { return self._s[10]! }
    public var UserInfo_DeleteContact: String { return self._s[11]! }
    public var ShareFileTip_CloseTip: String { return self._s[12]! }
    public var UserInfo_Invite: String { return self._s[13]! }
    public var Passport_Identity_MiddleName: String { return self._s[14]! }
    public var Passport_Identity_FrontSideHelp: String { return self._s[15]! }
    public var Month_GenDecember: String { return self._s[17]! }
    public var Common_Yes: String { return self._s[18]! }
    public func EncryptionKey_Description(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[19]!, self._r[19]!, [_1, _2])
    }
    public var Channel_AdminLogFilter_EventsLeaving: String { return self._s[20]! }
    public var WallpaperPreview_PreviewBottomText: String { return self._s[21]! }
    public func Notification_PinnedStickerMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[22]!, self._r[22]!, [_0])
    }
    public var Passport_Address_ScansHelp: String { return self._s[23]! }
    public var FastTwoStepSetup_PasswordHelp: String { return self._s[24]! }
    public var LastSeen_Lately: String { return self._s[29]! }
    public var Channel_EditAdmin_PermissinAddAdminOff: String { return self._s[30]! }
    public var Camera_Discard: String { return self._s[31]! }
    public var Login_InvalidPhoneError: String { return self._s[32]! }
    public var Conversation_Moderate_Delete: String { return self._s[34]! }
    public var Conversation_DeleteMessagesForEveryone: String { return self._s[35]! }
    public var WatchRemote_AlertOpen: String { return self._s[36]! }
    public func MediaPicker_Nof(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[37]!, self._r[37]!, [_0])
    }
    public var Watch_GroupInfo_Title: String { return self._s[39]! }
    public var Passport_Identity_AddPersonalDetails: String { return self._s[40]! }
    public var Channel_Info_Members: String { return self._s[41]! }
    public var LoginPassword_InvalidPasswordError: String { return self._s[43]! }
    public var Conversation_LiveLocation: String { return self._s[44]! }
    public var PrivacyLastSeenSettings_CustomShareSettingsHelp: String { return self._s[45]! }
    public var NetworkUsageSettings_BytesReceived: String { return self._s[47]! }
    public var Stickers_Search: String { return self._s[49]! }
    public var NotificationsSound_Synth: String { return self._s[50]! }
    public var NetworkUsageSettings_MediaAudioDataSection: String { return self._s[52]! }
    public var AutoNightTheme_UseSunsetSunrise: String { return self._s[53]! }
    public var FastTwoStepSetup_Title: String { return self._s[54]! }
    public var Channel_Info_BlackList: String { return self._s[55]! }
    public var Channel_AdminLog_InfoPanelTitle: String { return self._s[56]! }
    public var Conversation_OpenFile: String { return self._s[57]! }
    public var SecretTimer_ImageDescription: String { return self._s[58]! }
    public var StickerSettings_ContextInfo: String { return self._s[59]! }
    public var TwoStepAuth_GenericHelp: String { return self._s[61]! }
    public var AutoDownloadSettings_Unlimited: String { return self._s[62]! }
    public var PrivacyLastSeenSettings_NeverShareWith_Title: String { return self._s[63]! }
    public func PUSH_CHAT_MESSAGE_VIDEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[64]!, self._r[64]!, [_1, _2])
    }
    public var Notifications_AddExceptionTitle: String { return self._s[65]! }
    public var Watch_MessageView_Reply: String { return self._s[66]! }
    public var Tour_Text6: String { return self._s[67]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordChange: String { return self._s[68]! }
    public func Notification_PinnedAnimationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[69]!, self._r[69]!, [_0])
    }
    public func ShareFileTip_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[70]!, self._r[70]!, [_0])
    }
    public var AccessDenied_LocationDenied: String { return self._s[71]! }
    public var CallSettings_RecentCalls: String { return self._s[72]! }
    public var ConversationProfile_LeaveDeleteAndExit: String { return self._s[73]! }
    public var Channel_Members_AddAdminErrorBlacklisted: String { return self._s[74]! }
    public var Passport_Authorize: String { return self._s[75]! }
    public var StickerPacksSettings_ArchivedMasks_Info: String { return self._s[76]! }
    public var TwoStepAuth_ReEnterPasswordTitle: String { return self._s[77]! }
    public var Tour_StartButton: String { return self._s[78]! }
    public var Watch_AppName: String { return self._s[80]! }
    public var StickerPack_ErrorNotFound: String { return self._s[81]! }
    public var Channel_Info_Subscribers: String { return self._s[82]! }
    public func Channel_AdminLog_MessageGroupPreHistoryVisible(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[83]!, self._r[83]!, [_0])
    }
    public func DialogList_PinLimitError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[84]!, self._r[84]!, [_0])
    }
    public var Conversation_StopLiveLocation: String { return self._s[86]! }
    public var Channel_AdminLogFilter_EventsAll: String { return self._s[87]! }
    public var GroupInfo_InviteLink_CopyAlert_Success: String { return self._s[89]! }
    public var Username_LinkCopied: String { return self._s[91]! }
    public var GroupRemoved_Title: String { return self._s[92]! }
    public var SecretVideo_Title: String { return self._s[93]! }
    public func PUSH_PINNED_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[94]!, self._r[94]!, [_1])
    }
    public var AccessDenied_PhotosAndVideos: String { return self._s[95]! }
    public func PUSH_CHANNEL_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[96]!, self._r[96]!, [_1])
    }
    public var Map_OpenInGoogleMaps: String { return self._s[97]! }
    public func Time_PreciseDate_m12(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[98]!, self._r[98]!, [_1, _2, _3])
    }
    public func Channel_AdminLog_MessageKickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[99]!, self._r[99]!, [_1, _2])
    }
    public var Call_StatusRinging: String { return self._s[100]! }
    public var Group_Username_InvalidStartsWithNumber: String { return self._s[101]! }
    public var UserInfo_NotificationsEnabled: String { return self._s[102]! }
    public var Map_Search: String { return self._s[103]! }
    public var Login_TermsOfServiceHeader: String { return self._s[105]! }
    public func Notification_PinnedVideoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[106]!, self._r[106]!, [_0])
    }
    public func Channel_AdminLog_MessageToggleSignaturesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[107]!, self._r[107]!, [_0])
    }
    public var TwoStepAuth_SetupPasswordConfirmPassword: String { return self._s[108]! }
    public var Weekday_Today: String { return self._s[109]! }
    public func InstantPage_AuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[111]!, self._r[111]!, [_1, _2])
    }
    public func Conversation_MessageDialogRetryAll(_ _1: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[112]!, self._r[112]!, ["\(_1)"])
    }
    public var Notification_PassportValuePersonalDetails: String { return self._s[114]! }
    public var Channel_AdminLog_MessagePreviousLink: String { return self._s[115]! }
    public var ChangePhoneNumberNumber_NewNumber: String { return self._s[116]! }
    public var ApplyLanguage_LanguageNotSupportedError: String { return self._s[117]! }
    public var TwoStepAuth_ChangePasswordDescription: String { return self._s[118]! }
    public var PhotoEditor_BlurToolLinear: String { return self._s[119]! }
    public var Contacts_PermissionsAllowInSettings: String { return self._s[120]! }
    public var Weekday_ShortMonday: String { return self._s[121]! }
    public var Cache_KeepMedia: String { return self._s[122]! }
    public var Passport_FieldIdentitySelfieHelp: String { return self._s[123]! }
    public func PUSH_PINNED_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[124]!, self._r[124]!, [_1, _2])
    }
    public var Conversation_ClousStorageInfo_Description4: String { return self._s[125]! }
    public var Passport_Language_ru: String { return self._s[126]! }
    public func Notification_CreatedChatWithTitle(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[127]!, self._r[127]!, [_0, _1])
    }
    public var WallpaperPreview_PatternIntensity: String { return self._s[128]! }
    public var TwoStepAuth_RecoveryUnavailable: String { return self._s[129]! }
    public var EnterPasscode_TouchId: String { return self._s[130]! }
    public var PhotoEditor_QualityVeryHigh: String { return self._s[133]! }
    public var Checkout_NewCard_SaveInfo: String { return self._s[135]! }
    public var ChatSettings_AutoDownloadEnabled: String { return self._s[138]! }
    public var NetworkUsageSettings_BytesSent: String { return self._s[139]! }
    public var Checkout_PasswordEntry_Pay: String { return self._s[140]! }
    public var AuthSessions_TerminateSession: String { return self._s[141]! }
    public var Message_File: String { return self._s[142]! }
    public var MediaPicker_VideoMuteDescription: String { return self._s[143]! }
    public var SocksProxySetup_ProxyStatusConnected: String { return self._s[144]! }
    public var TwoStepAuth_RecoveryCode: String { return self._s[145]! }
    public var EnterPasscode_EnterCurrentPasscode: String { return self._s[146]! }
    public func TwoStepAuth_EnterPasswordHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[147]!, self._r[147]!, [_0])
    }
    public var Conversation_Moderate_Report: String { return self._s[149]! }
    public var TwoStepAuth_EmailInvalid: String { return self._s[150]! }
    public var Passport_Language_ms: String { return self._s[151]! }
    public var Channel_Edit_AboutItem: String { return self._s[153]! }
    public var DialogList_SearchSectionGlobal: String { return self._s[157]! }
    public var AttachmentMenu_WebSearch: String { return self._s[158]! }
    public var PasscodeSettings_TurnPasscodeOn: String { return self._s[159]! }
    public var Channel_BanUser_Title: String { return self._s[160]! }
    public var WallpaperPreview_SwipeTopText: String { return self._s[161]! }
    public var ChatSearch_SearchPlaceholder: String { return self._s[163]! }
    public var Passport_FieldAddressTranslationHelp: String { return self._s[164]! }
    public var NotificationsSound_Aurora: String { return self._s[165]! }
    public func FileSize_GB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[166]!, self._r[166]!, [_0])
    }
    public var AuthSessions_LoggedInWithTelegram: String { return self._s[169]! }
    public func Privacy_GroupsAndChannels_InviteToGroupError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[170]!, self._r[170]!, [_0, _1])
    }
    public var Passport_PasswordNext: String { return self._s[171]! }
    public var Bot_GroupStatusReadsHistory: String { return self._s[172]! }
    public var EmptyGroupInfo_Line2: String { return self._s[173]! }
    public var Settings_FAQ_Intro: String { return self._s[175]! }
    public var PrivacySettings_PasscodeAndTouchId: String { return self._s[177]! }
    public var FeaturedStickerPacks_Title: String { return self._s[178]! }
    public var TwoStepAuth_PasswordRemoveConfirmation: String { return self._s[179]! }
    public var Username_Title: String { return self._s[180]! }
    public func Message_StickerText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[181]!, self._r[181]!, [_0])
    }
    public var Localization_LanguageOther: String { return self._s[182]! }
    public var Stickers_SuggestStickers: String { return self._s[183]! }
    public func Channel_AdminLog_MessageRemovedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[184]!, self._r[184]!, [_0])
    }
    public var Channel_AdminLogFilter_EventsAdmins: String { return self._s[185]! }
    public var Conversation_DefaultRestrictedStickers: String { return self._s[186]! }
    public func Notification_PinnedDeletedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[187]!, self._r[187]!, [_0])
    }
    public var Group_UpgradeConfirmation: String { return self._s[189]! }
    public var DialogList_Unpin: String { return self._s[190]! }
    public var Passport_Identity_DateOfBirth: String { return self._s[191]! }
    public var Month_ShortOctober: String { return self._s[192]! }
    public var Notification_CallCanceledShort: String { return self._s[193]! }
    public var Passport_Phone_Help: String { return self._s[194]! }
    public var Passport_Language_az: String { return self._s[196]! }
    public var CreatePoll_TextPlaceholder: String { return self._s[198]! }
    public var Passport_Identity_DocumentNumber: String { return self._s[199]! }
    public var PhotoEditor_CurvesRed: String { return self._s[200]! }
    public var PhoneNumberHelp_Alert: String { return self._s[202]! }
    public var SocksProxySetup_Port: String { return self._s[203]! }
    public var Checkout_PayNone: String { return self._s[204]! }
    public var AutoDownloadSettings_WiFi: String { return self._s[205]! }
    public var GroupInfo_GroupType: String { return self._s[206]! }
    public var StickerSettings_ContextHide: String { return self._s[207]! }
    public var Passport_Address_OneOfTypeTemporaryRegistration: String { return self._s[208]! }
    public var Group_Setup_HistoryTitle: String { return self._s[210]! }
    public var Passport_Identity_FilesUploadNew: String { return self._s[211]! }
    public var PasscodeSettings_AutoLock: String { return self._s[212]! }
    public var Passport_Title: String { return self._s[213]! }
    public var Channel_AdminLogFilter_EventsNewSubscribers: String { return self._s[214]! }
    public var GroupPermission_NoSendGifs: String { return self._s[215]! }
    public var State_WaitingForNetwork: String { return self._s[217]! }
    public func Notification_Invited(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[218]!, self._r[218]!, [_0, _1])
    }
    public var Calls_NotNow: String { return self._s[220]! }
    public var UserInfo_SendMessage: String { return self._s[221]! }
    public var TwoStepAuth_PasswordSet: String { return self._s[222]! }
    public var Passport_DeleteDocument: String { return self._s[223]! }
    public var SocksProxySetup_AddProxyTitle: String { return self._s[224]! }
    public func PUSH_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[225]!, self._r[225]!, [_1])
    }
    public var GroupRemoved_Remove: String { return self._s[226]! }
    public var Passport_FieldIdentity: String { return self._s[227]! }
    public var Group_Setup_TypePrivateHelp: String { return self._s[228]! }
    public var Conversation_Processing: String { return self._s[230]! }
    public var ChatSettings_AutoPlayAnimations: String { return self._s[232]! }
    public var AuthSessions_LogOutApplicationsHelp: String { return self._s[235]! }
    public var Month_GenFebruary: String { return self._s[236]! }
    public func Login_InvalidPhoneEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[238]!, self._r[238]!, [_1, _2, _3, _4, _5])
    }
    public var Passport_Identity_TypeIdentityCard: String { return self._s[239]! }
    public var GroupInfo_AddParticipant: String { return self._s[241]! }
    public var KeyCommand_SendMessage: String { return self._s[242]! }
    public var Map_LiveLocationShowAll: String { return self._s[244]! }
    public var WallpaperSearch_ColorOrange: String { return self._s[246]! }
    public var Checkout_Receipt_Title: String { return self._s[247]! }
    public var WallpaperPreview_PreviewTopText: String { return self._s[248]! }
    public var Message_Contact: String { return self._s[249]! }
    public var Call_StatusIncoming: String { return self._s[250]! }
    public func Channel_AdminLog_MessageKickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[251]!, self._r[251]!, [_1])
    }
    public func PUSH_ENCRYPTED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[253]!, self._r[253]!, [_1])
    }
    public var Passport_FieldIdentityDetailsHelp: String { return self._s[254]! }
    public var Conversation_ViewChannel: String { return self._s[255]! }
    public func Time_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[256]!, self._r[256]!, [_0])
    }
    public var Passport_Language_nl: String { return self._s[258]! }
    public var Camera_Retake: String { return self._s[259]! }
    public var AuthSessions_LogOutApplications: String { return self._s[260]! }
    public var ApplyLanguage_ApplySuccess: String { return self._s[261]! }
    public var Tour_Title6: String { return self._s[262]! }
    public var Map_ChooseAPlace: String { return self._s[263]! }
    public var CallSettings_Never: String { return self._s[265]! }
    public func Notification_ChangedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[266]!, self._r[266]!, [_0])
    }
    public var ChannelRemoved_RemoveInfo: String { return self._s[267]! }
    public var GroupInfo_InviteLink_Title: String { return self._s[268]! }
    public func Channel_AdminLog_MessageUnkickedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[269]!, self._r[269]!, [_1, _2])
    }
    public var KeyCommand_ScrollUp: String { return self._s[270]! }
    public var ContactInfo_URLLabelHomepage: String { return self._s[271]! }
    public func Conversation_EncryptedPlaceholderTitleOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[272]!, self._r[272]!, [_0])
    }
    public var CallFeedback_ReasonDistortedSpeech: String { return self._s[273]! }
    public var Watch_LastSeen_WithinAWeek: String { return self._s[274]! }
    public var Weekday_Tuesday: String { return self._s[276]! }
    public var UserInfo_StartSecretChat: String { return self._s[278]! }
    public var Passport_Identity_FilesTitle: String { return self._s[279]! }
    public var Permissions_NotificationsAllow_v0: String { return self._s[280]! }
    public var DialogList_DeleteConversationConfirmation: String { return self._s[282]! }
    public var AuthSessions_Sessions: String { return self._s[283]! }
    public var TwoStepAuth_RecoveryEmailChangeDescription: String { return self._s[285]! }
    public var Call_StatusWaiting: String { return self._s[286]! }
    public var CreateGroup_SoftUserLimitAlert: String { return self._s[287]! }
    public var FastTwoStepSetup_HintHelp: String { return self._s[288]! }
    public var WallpaperPreview_CustomColorBottomText: String { return self._s[289]! }
    public var Settings_LogoutConfirmationText: String { return self._s[290]! }
    public var Passport_Identity_TypePassport: String { return self._s[292]! }
    public var SocksProxySetup_SaveProxy: String { return self._s[295]! }
    public var AccessDenied_SaveMedia: String { return self._s[296]! }
    public var Checkout_ErrorInvoiceAlreadyPaid: String { return self._s[298]! }
    public var Settings_Title: String { return self._s[300]! }
    public var Contacts_InviteSearchLabel: String { return self._s[302]! }
    public var ConvertToSupergroup_Title: String { return self._s[303]! }
    public func Channel_AdminLog_CaptionEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[304]!, self._r[304]!, [_0])
    }
    public var InfoPlist_NSSiriUsageDescription: String { return self._s[305]! }
    public var ChatSettings_AutomaticPhotoDownload: String { return self._s[306]! }
    public var UserInfo_BotHelp: String { return self._s[307]! }
    public var PrivacySettings_LastSeenEverybody: String { return self._s[308]! }
    public var Checkout_Name: String { return self._s[309]! }
    public var Channel_BanUser_BlockFor: String { return self._s[310]! }
    public var Checkout_ShippingAddress: String { return self._s[311]! }
    public var Privacy_PaymentsClearInfoDoneHelp: String { return self._s[312]! }
    public var Channel_BanUser_PermissionSendPolls: String { return self._s[313]! }
    public func SecretVideo_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[316]!, self._r[316]!, [_0])
    }
    public var Contacts_SortedByName: String { return self._s[317]! }
    public var Group_LeaveGroup: String { return self._s[318]! }
    public var Settings_UsernameEmpty: String { return self._s[319]! }
    public func Notification_PinnedPollMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[320]!, self._r[320]!, [_0])
    }
    public func TwoStepAuth_ConfirmEmailDescription(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[321]!, self._r[321]!, [_1])
    }
    public var Message_ImageExpired: String { return self._s[322]! }
    public var TwoStepAuth_RecoveryFailed: String { return self._s[324]! }
    public var UserInfo_AddToExisting: String { return self._s[325]! }
    public var TwoStepAuth_EnabledSuccess: String { return self._s[326]! }
    public func PUSH_CHANNEL_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[327]!, self._r[327]!, [_1])
    }
    public var Notifications_GroupNotificationsAlert: String { return self._s[328]! }
    public var Passport_Language_km: String { return self._s[329]! }
    public var SocksProxySetup_AdNoticeHelp: String { return self._s[331]! }
    public var Notification_CallMissedShort: String { return self._s[332]! }
    public var ReportPeer_ReasonOther_Send: String { return self._s[333]! }
    public var Watch_Compose_Send: String { return self._s[334]! }
    public var Passport_Identity_TypeInternalPassportUploadScan: String { return self._s[337]! }
    public var Conversation_HoldForVideo: String { return self._s[338]! }
    public var CheckoutInfo_ErrorCityInvalid: String { return self._s[340]! }
    public var Appearance_AutoNightThemeDisabled: String { return self._s[342]! }
    public var Channel_LinkItem: String { return self._s[343]! }
    public func PrivacySettings_LastSeenContactsMinusPlus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[344]!, self._r[344]!, [_0, _1])
    }
    public func Passport_Identity_NativeNameTitle(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[347]!, self._r[347]!, [_0])
    }
    public var Passport_Language_dv: String { return self._s[348]! }
    public var Undo_LeftChannel: String { return self._s[349]! }
    public var Notifications_ExceptionsMuted: String { return self._s[350]! }
    public var Conversation_ContextMenuShare: String { return self._s[351]! }
    public var Conversation_ContextMenuStickerPackInfo: String { return self._s[352]! }
    public var ShareFileTip_Title: String { return self._s[353]! }
    public var NotificationsSound_Chord: String { return self._s[354]! }
    public func PUSH_CHAT_RETURNED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[355]!, self._r[355]!, [_1, _2])
    }
    public var Passport_Address_EditTemporaryRegistration: String { return self._s[356]! }
    public func Notification_Joined(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[357]!, self._r[357]!, [_0])
    }
    public var Notification_CallOutgoingShort: String { return self._s[359]! }
    public func Watch_Time_ShortFullAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[360]!, self._r[360]!, [_1, _2])
    }
    public var Passport_Address_TypeUtilityBill: String { return self._s[361]! }
    public var ReportPeer_Report: String { return self._s[362]! }
    public var GroupInfo_DeactivatedStatus: String { return self._s[363]! }
    public var StickerPack_Send: String { return self._s[364]! }
    public var Login_CodeSentInternal: String { return self._s[365]! }
    public var GroupInfo_InviteLink_LinkSection: String { return self._s[366]! }
    public func Channel_AdminLog_MessageDeleted(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[367]!, self._r[367]!, [_0])
    }
    public func Conversation_EncryptionWaiting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[369]!, self._r[369]!, [_0])
    }
    public var Channel_BanUser_PermissionSendStickersAndGifs: String { return self._s[370]! }
    public func PUSH_PINNED_GAME(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[371]!, self._r[371]!, [_1])
    }
    public var ReportPeer_ReasonViolence: String { return self._s[373]! }
    public var Map_Locating: String { return self._s[374]! }
    public var AutoDownloadSettings_GroupChats: String { return self._s[376]! }
    public var CheckoutInfo_SaveInfo: String { return self._s[377]! }
    public var SharedMedia_EmptyLinksText: String { return self._s[379]! }
    public var Passport_Address_CityPlaceholder: String { return self._s[380]! }
    public var CheckoutInfo_ErrorStateInvalid: String { return self._s[381]! }
    public var Channel_AdminLog_CanAddAdmins: String { return self._s[383]! }
    public func PUSH_CHANNEL_MESSAGE_FWD(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[384]!, self._r[384]!, [_1])
    }
    public func Time_MonthOfYear_m8(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[385]!, self._r[385]!, [_0])
    }
    public var InfoPlist_NSLocationWhenInUseUsageDescription: String { return self._s[386]! }
    public var GroupInfo_InviteLink_RevokeAlert_Success: String { return self._s[387]! }
    public var ChangePhoneNumberCode_Code: String { return self._s[388]! }
    public func UserInfo_NotificationsDefaultSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[389]!, self._r[389]!, [_0])
    }
    public var TwoStepAuth_SetupEmail: String { return self._s[390]! }
    public var HashtagSearch_AllChats: String { return self._s[391]! }
    public var PhotoEditor_QualityHigh: String { return self._s[394]! }
    public func Passport_Phone_UseTelegramNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[395]!, self._r[395]!, [_0])
    }
    public var ApplyLanguage_ApplyLanguageAction: String { return self._s[396]! }
    public var Message_LiveLocation: String { return self._s[397]! }
    public var Cache_LowDiskSpaceText: String { return self._s[398]! }
    public var Conversation_SendMessage: String { return self._s[399]! }
    public var AuthSessions_EmptyTitle: String { return self._s[400]! }
    public var CallSettings_UseLessData: String { return self._s[401]! }
    public var NetworkUsageSettings_MediaDocumentDataSection: String { return self._s[402]! }
    public var Stickers_AddToFavorites: String { return self._s[403]! }
    public var PhotoEditor_QualityLow: String { return self._s[404]! }
    public var Watch_UserInfo_Unblock: String { return self._s[405]! }
    public var Settings_Logout: String { return self._s[406]! }
    public func PUSH_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[407]!, self._r[407]!, [_1])
    }
    public var ContactInfo_PhoneLabelWork: String { return self._s[408]! }
    public func Date_ChatDateHeader(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[409]!, self._r[409]!, [_1, _2])
    }
    public func Message_ForwardedMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[410]!, self._r[410]!, [_0])
    }
    public var Watch_Notification_Joined: String { return self._s[411]! }
    public var Group_Setup_TypePublicHelp: String { return self._s[412]! }
    public var Passport_Scans_UploadNew: String { return self._s[413]! }
    public var Checkout_LiabilityAlertTitle: String { return self._s[414]! }
    public var DialogList_Title: String { return self._s[417]! }
    public var NotificationSettings_ContactJoined: String { return self._s[418]! }
    public var GroupInfo_LabelAdmin: String { return self._s[419]! }
    public var KeyCommand_ChatInfo: String { return self._s[420]! }
    public var Conversation_EditingCaptionPanelTitle: String { return self._s[421]! }
    public var Call_ReportIncludeLog: String { return self._s[422]! }
    public func Notifications_ExceptionsChangeSound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[425]!, self._r[425]!, [_0])
    }
    public var ChatAdmins_AllMembersAreAdmins: String { return self._s[426]! }
    public var Conversation_DefaultRestrictedInline: String { return self._s[427]! }
    public var Message_Sticker: String { return self._s[428]! }
    public var LastSeen_JustNow: String { return self._s[430]! }
    public var Passport_Email_EmailPlaceholder: String { return self._s[432]! }
    public var Channel_AdminLogFilter_EventsEditedMessages: String { return self._s[433]! }
    public var Channel_EditAdmin_PermissionsHeader: String { return self._s[434]! }
    public var TwoStepAuth_Email: String { return self._s[435]! }
    public var PhotoEditor_BlurToolOff: String { return self._s[436]! }
    public var Message_PinnedStickerMessage: String { return self._s[437]! }
    public var ContactInfo_PhoneLabelPager: String { return self._s[438]! }
    public var Passport_DiscardMessageTitle: String { return self._s[439]! }
    public var Privacy_PaymentsTitle: String { return self._s[440]! }
    public var Appearance_ColorTheme: String { return self._s[442]! }
    public var UserInfo_ShareContact: String { return self._s[443]! }
    public var Watch_Message_Call: String { return self._s[444]! }
    public var Common_More: String { return self._s[445]! }
    public var Passport_Address_TypePassportRegistration: String { return self._s[446]! }
    public var Profile_EncryptionKey: String { return self._s[449]! }
    public var Privacy_TopPeers: String { return self._s[450]! }
    public var Conversation_StopPollConfirmation: String { return self._s[451]! }
    public var Privacy_TopPeersWarning: String { return self._s[453]! }
    public func PUSH_CHANNEL_MESSAGES(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[455]!, self._r[455]!, [_1, _2])
    }
    public var DialogList_SearchSectionMessages: String { return self._s[457]! }
    public var Notifications_ChannelNotifications: String { return self._s[458]! }
    public var CheckoutInfo_ShippingInfoAddress1Placeholder: String { return self._s[459]! }
    public var Passport_Language_sk: String { return self._s[460]! }
    public var Notification_MessageLifetime1h: String { return self._s[461]! }
    public var Wallpaper_ResetWallpapersInfo: String { return self._s[462]! }
    public var Call_ReportSkip: String { return self._s[464]! }
    public var Cache_ServiceFiles: String { return self._s[465]! }
    public var Group_ErrorAddTooMuchAdmins: String { return self._s[466]! }
    public var Map_Hybrid: String { return self._s[467]! }
    public var ChatSettings_AutoDownloadVideos: String { return self._s[470]! }
    public var Channel_BanUser_PermissionEmbedLinks: String { return self._s[471]! }
    public var InfoPlist_NSLocationAlwaysAndWhenInUseUsageDescription: String { return self._s[472]! }
    public var SocksProxySetup_ProxyTelegram: String { return self._s[475]! }
    public func PUSH_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[476]!, self._r[476]!, [_1])
    }
    public var Channel_Username_CreatePrivateLinkHelp: String { return self._s[478]! }
    public func PUSH_CHAT_TITLE_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[479]!, self._r[479]!, [_1, _2])
    }
    public var Conversation_LiveLocationYou: String { return self._s[480]! }
    public var UserInfo_ShareBot: String { return self._s[483]! }
    public func PUSH_AUTH_REGION(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[484]!, self._r[484]!, [_1, _2])
    }
    public var PhotoEditor_ShadowsTint: String { return self._s[485]! }
    public var Message_Audio: String { return self._s[486]! }
    public var Passport_Language_lt: String { return self._s[487]! }
    public func Message_PinnedTextMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[488]!, self._r[488]!, [_0])
    }
    public var Permissions_SiriText_v0: String { return self._s[489]! }
    public var Conversation_FileICloudDrive: String { return self._s[490]! }
    public var Notifications_Badge_IncludeMutedChats: String { return self._s[491]! }
    public func Notification_NewAuthDetected(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[492]!, self._r[492]!, [_1, _2, _3, _4, _5, _6])
    }
    public var DialogList_ProxyConnectionIssuesTooltip: String { return self._s[493]! }
    public func Time_MonthOfYear_m5(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[494]!, self._r[494]!, [_0])
    }
    public var Channel_SignMessages: String { return self._s[495]! }
    public func PUSH_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[496]!, self._r[496]!, [_1])
    }
    public var Compose_ChannelTokenListPlaceholder: String { return self._s[497]! }
    public var Passport_ScanPassport: String { return self._s[498]! }
    public var Watch_Message_Invoice: String { return self._s[499]! }
    public var Watch_Suggestion_Thanks: String { return self._s[500]! }
    public func PUSH_CHAT_MESSAGE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[501]!, self._r[501]!, [_1, _2])
    }
    public var BlockedUsers_AddNew: String { return self._s[502]! }
    public var Month_GenJuly: String { return self._s[503]! }
    public var SocksProxySetup_ProxySocks5: String { return self._s[504]! }
    public var Notification_ChannelInviterSelf: String { return self._s[506]! }
    public var CheckoutInfo_ReceiverInfoEmail: String { return self._s[507]! }
    public func ApplyLanguage_ChangeLanguageUnofficialText(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[508]!, self._r[508]!, [_1, _2])
    }
    public var CheckoutInfo_Title: String { return self._s[509]! }
    public var Watch_Stickers_RecentPlaceholder: String { return self._s[510]! }
    public func Map_DistanceAway(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[511]!, self._r[511]!, [_0])
    }
    public var Passport_Identity_MainPage: String { return self._s[512]! }
    public var TwoStepAuth_ConfirmEmailResendCode: String { return self._s[513]! }
    public var Passport_Language_de: String { return self._s[514]! }
    public var Update_Title: String { return self._s[515]! }
    public var ContactInfo_PhoneLabelWorkFax: String { return self._s[516]! }
    public var Channel_AdminLog_BanEmbedLinks: String { return self._s[517]! }
    public var Passport_Email_UseTelegramEmailHelp: String { return self._s[518]! }
    public var Notifications_ChannelNotificationsPreview: String { return self._s[519]! }
    public var NotificationsSound_Telegraph: String { return self._s[520]! }
    public var Watch_LastSeen_ALongTimeAgo: String { return self._s[521]! }
    public var ChannelMembers_WhoCanAddMembers: String { return self._s[522]! }
    public func AutoDownloadSettings_UpTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[523]!, self._r[523]!, [_0])
    }
    public var Stickers_SuggestAll: String { return self._s[524]! }
    public var Conversation_ForwardTitle: String { return self._s[525]! }
    public func Notification_JoinedChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[526]!, self._r[526]!, [_0])
    }
    public var Calls_NewCall: String { return self._s[527]! }
    public var Call_StatusEnded: String { return self._s[528]! }
    public var Settings_ProxyConnected: String { return self._s[529]! }
    public var Channel_AdminLogFilter_EventsPinned: String { return self._s[530]! }
    public var PhotoEditor_QualityVeryLow: String { return self._s[531]! }
    public var Channel_AdminLogFilter_EventsDeletedMessages: String { return self._s[532]! }
    public var Passport_PasswordPlaceholder: String { return self._s[533]! }
    public var Message_PinnedInvoice: String { return self._s[534]! }
    public var Passport_Identity_IssueDate: String { return self._s[535]! }
    public var Passport_Language_pl: String { return self._s[536]! }
    public func ChannelInfo_ChannelForbidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[537]!, self._r[537]!, [_0])
    }
    public var SocksProxySetup_PasteFromClipboard: String { return self._s[538]! }
    public var Call_StatusConnecting: String { return self._s[539]! }
    public func Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[540]!, self._r[540]!, [_0])
    }
    public var ChatSettings_ConnectionType_UseProxy: String { return self._s[542]! }
    public var Common_Edit: String { return self._s[543]! }
    public var PrivacySettings_LastSeenNobody: String { return self._s[544]! }
    public func Notification_LeftChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[545]!, self._r[545]!, [_0])
    }
    public var GroupInfo_ChatAdmins: String { return self._s[546]! }
    public var PrivateDataSettings_Title: String { return self._s[547]! }
    public var Login_CancelPhoneVerificationStop: String { return self._s[548]! }
    public var ChatList_Read: String { return self._s[549]! }
    public var GroupPermission_SectionTitle: String { return self._s[550]! }
    public func PUSH_CHAT_LEFT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[552]!, self._r[552]!, [_1, _2])
    }
    public var Checkout_ErrorPaymentFailed: String { return self._s[553]! }
    public var Update_UpdateApp: String { return self._s[554]! }
    public var Group_Username_RevokeExistingUsernamesInfo: String { return self._s[555]! }
    public var Settings_Appearance: String { return self._s[556]! }
    public var Watch_Location_Access: String { return self._s[558]! }
    public var ShareMenu_CopyShareLink: String { return self._s[560]! }
    public var TwoStepAuth_SetupHintTitle: String { return self._s[561]! }
    public func DialogList_SingleRecordingVideoMessageSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[563]!, self._r[563]!, [_0])
    }
    public var Notifications_ClassicTones: String { return self._s[564]! }
    public var Weekday_ShortWednesday: String { return self._s[565]! }
    public var WallpaperPreview_SwipeColorsBottomText: String { return self._s[566]! }
    public var Undo_LeftGroup: String { return self._s[569]! }
    public var Conversation_LinkDialogCopy: String { return self._s[570]! }
    public var KeyCommand_FocusOnInputField: String { return self._s[571]! }
    public var Contacts_SelectAll: String { return self._s[572]! }
    public var Preview_SaveToCameraRoll: String { return self._s[573]! }
    public var Wallpaper_Title: String { return self._s[574]! }
    public var Conversation_FilePhotoOrVideo: String { return self._s[575]! }
    public var AccessDenied_Camera: String { return self._s[576]! }
    public var Watch_Compose_CurrentLocation: String { return self._s[577]! }
    public func SecretImage_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[579]!, self._r[579]!, [_0])
    }
    public var GroupInfo_InvitationLinkDoesNotExist: String { return self._s[580]! }
    public var Passport_Language_ro: String { return self._s[581]! }
    public var CheckoutInfo_SaveInfoHelp: String { return self._s[582]! }
    public func Notification_SecretChatMessageScreenshot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[583]!, self._r[583]!, [_0])
    }
    public var Login_CancelPhoneVerification: String { return self._s[584]! }
    public var State_ConnectingToProxy: String { return self._s[585]! }
    public var Calls_RatingTitle: String { return self._s[586]! }
    public var Generic_ErrorMoreInfo: String { return self._s[587]! }
    public var Appearance_PreviewReplyText: String { return self._s[588]! }
    public var CheckoutInfo_ShippingInfoPostcodePlaceholder: String { return self._s[589]! }
    public var SharedMedia_CategoryLinks: String { return self._s[590]! }
    public var Calls_Missed: String { return self._s[591]! }
    public var Cache_Photos: String { return self._s[595]! }
    public var GroupPermission_NoAddMembers: String { return self._s[596]! }
    public func Channel_AdminLog_MessageUnpinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[597]!, self._r[597]!, [_0])
    }
    public var Conversation_ShareBotLocationConfirmationTitle: String { return self._s[598]! }
    public var Settings_ProxyDisabled: String { return self._s[599]! }
    public func Settings_ApplyProxyAlertCredentials(_ _1: String, _ _2: String, _ _3: String, _ _4: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[600]!, self._r[600]!, [_1, _2, _3, _4])
    }
    public func Conversation_RestrictedMediaTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[601]!, self._r[601]!, [_0])
    }
    public var Appearance_Title: String { return self._s[602]! }
    public func Time_MonthOfYear_m2(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[604]!, self._r[604]!, [_0])
    }
    public var StickerPacksSettings_ShowStickersButtonHelp: String { return self._s[605]! }
    public var Channel_EditMessageErrorGeneric: String { return self._s[606]! }
    public var Privacy_Calls_IntegrationHelp: String { return self._s[607]! }
    public var Preview_DeletePhoto: String { return self._s[608]! }
    public var PrivacySettings_PrivacyTitle: String { return self._s[609]! }
    public func Conversation_BotInteractiveUrlAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[610]!, self._r[610]!, [_0])
    }
    public var Coub_TapForSound: String { return self._s[612]! }
    public var Map_LocatingError: String { return self._s[613]! }
    public var TwoStepAuth_EmailChangeSuccess: String { return self._s[615]! }
    public var Passport_ForgottenPassword: String { return self._s[616]! }
    public var GroupInfo_InviteLink_RevokeLink: String { return self._s[617]! }
    public var StickerPacksSettings_ArchivedPacks: String { return self._s[618]! }
    public var Login_TermsOfServiceSignupDecline: String { return self._s[620]! }
    public var Channel_Moderator_AccessLevelRevoke: String { return self._s[621]! }
    public var Message_Location: String { return self._s[622]! }
    public var Passport_Identity_NamePlaceholder: String { return self._s[623]! }
    public var Channel_Management_Title: String { return self._s[624]! }
    public var DialogList_SearchSectionDialogs: String { return self._s[626]! }
    public var Compose_NewChannel_Members: String { return self._s[627]! }
    public func DialogList_SingleUploadingFileSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[628]!, self._r[628]!, [_0])
    }
    public var AutoNightTheme_ScheduledFrom: String { return self._s[629]! }
    public var PhotoEditor_WarmthTool: String { return self._s[630]! }
    public var Passport_Language_tr: String { return self._s[631]! }
    public var Login_ResetAccountProtected_Reset: String { return self._s[633]! }
    public var Watch_PhotoView_Title: String { return self._s[634]! }
    public var Passport_Phone_Delete: String { return self._s[635]! }
    public var Conversation_EditingMessageMediaEditCurrentPhoto: String { return self._s[636]! }
    public var GroupInfo_Permissions: String { return self._s[637]! }
    public var PasscodeSettings_TurnPasscodeOff: String { return self._s[638]! }
    public var Profile_ShareContactButton: String { return self._s[639]! }
    public var ChatSettings_Other: String { return self._s[640]! }
    public var UserInfo_NotificationsDisabled: String { return self._s[641]! }
    public var CheckoutInfo_ShippingInfoCity: String { return self._s[642]! }
    public func PUSH_CHAT_MESSAGE_PHOTOS(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[643]!, self._r[643]!, [_1, _2, _3])
    }
    public var LastSeen_WithinAMonth: String { return self._s[644]! }
    public var Conversation_EncryptionCanceled: String { return self._s[645]! }
    public var MediaPicker_GroupDescription: String { return self._s[646]! }
    public var WebSearch_Images: String { return self._s[647]! }
    public func Channel_Management_PromotedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[648]!, self._r[648]!, [_0])
    }
    public var Message_Photo: String { return self._s[649]! }
    public var PasscodeSettings_HelpBottom: String { return self._s[650]! }
    public var AutoDownloadSettings_VideosTitle: String { return self._s[651]! }
    public var Passport_Identity_AddDriversLicense: String { return self._s[652]! }
    public var TwoStepAuth_EnterPasswordPassword: String { return self._s[653]! }
    public var NotificationsSound_Calypso: String { return self._s[654]! }
    public var Map_Map: String { return self._s[655]! }
    public var CheckoutInfo_ReceiverInfoTitle: String { return self._s[657]! }
    public var ChatSettings_TextSizeUnits: String { return self._s[658]! }
    public var Common_of: String { return self._s[659]! }
    public var Conversation_ForwardContacts: String { return self._s[661]! }
    public var Passport_Language_hy: String { return self._s[663]! }
    public var Notifications_MessageNotificationsHelp: String { return self._s[664]! }
    public var AutoDownloadSettings_Reset: String { return self._s[665]! }
    public var Paint_ClearConfirm: String { return self._s[666]! }
    public var Camera_VideoMode: String { return self._s[667]! }
    public func Conversation_RestrictedStickersTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[668]!, self._r[668]!, [_0])
    }
    public var Privacy_Calls_AlwaysAllow_Placeholder: String { return self._s[669]! }
    public var Conversation_ViewBackground: String { return self._s[670]! }
    public var Passport_Language_el: String { return self._s[671]! }
    public var PhotoEditor_Original: String { return self._s[672]! }
    public var Settings_FAQ_Button: String { return self._s[674]! }
    public var Channel_Setup_PublicNoLink: String { return self._s[676]! }
    public var Conversation_UnsupportedMedia: String { return self._s[677]! }
    public var Conversation_SlideToCancel: String { return self._s[678]! }
    public var Passport_Identity_OneOfTypeInternalPassport: String { return self._s[679]! }
    public var CheckoutInfo_ShippingInfoPostcode: String { return self._s[680]! }
    public var AutoNightTheme_NotAvailable: String { return self._s[681]! }
    public var Common_Create: String { return self._s[682]! }
    public var Settings_ApplyProxyAlertEnable: String { return self._s[683]! }
    public var Localization_ChooseLanguage: String { return self._s[685]! }
    public var Settings_Proxy: String { return self._s[688]! }
    public var Privacy_TopPeersHelp: String { return self._s[689]! }
    public var CheckoutInfo_ShippingInfoCountryPlaceholder: String { return self._s[690]! }
    public var TwoStepAuth_ConfirmationAbort: String { return self._s[691]! }
    public func Contacts_AccessDeniedHelpPortrait(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[693]!, self._r[693]!, [_0])
    }
    public var Contacts_SortedByPresence: String { return self._s[694]! }
    public var Passport_Identity_SurnamePlaceholder: String { return self._s[695]! }
    public var Cache_Title: String { return self._s[696]! }
    public func Login_PhoneBannedEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[697]!, self._r[697]!, [_0])
    }
    public var TwoStepAuth_EmailCodeExpired: String { return self._s[698]! }
    public var Channel_Moderator_Title: String { return self._s[699]! }
    public var InstantPage_AutoNightTheme: String { return self._s[701]! }
    public func PUSH_MESSAGE_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[704]!, self._r[704]!, [_1])
    }
    public var Passport_Scans_Upload: String { return self._s[705]! }
    public var Undo_Undo: String { return self._s[707]! }
    public var Contacts_AccessDeniedHelpON: String { return self._s[708]! }
    public var TwoStepAuth_RemovePassword: String { return self._s[709]! }
    public var Common_Delete: String { return self._s[710]! }
    public var Conversation_ContextMenuDelete: String { return self._s[712]! }
    public var SocksProxySetup_Credentials: String { return self._s[713]! }
    public var PasscodeSettings_AutoLock_Disabled: String { return self._s[715]! }
    public var Passport_Address_OneOfTypeRentalAgreement: String { return self._s[718]! }
    public var Conversation_ShareBotContactConfirmationTitle: String { return self._s[719]! }
    public var Passport_Language_id: String { return self._s[721]! }
    public var WallpaperSearch_ColorTeal: String { return self._s[722]! }
    public var ChannelIntro_Title: String { return self._s[723]! }
    public func Channel_AdminLog_MessageToggleSignaturesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[724]!, self._r[724]!, [_0])
    }
    public var Channel_Info_Description: String { return self._s[726]! }
    public var Stickers_FavoriteStickers: String { return self._s[727]! }
    public var Channel_BanUser_PermissionAddMembers: String { return self._s[728]! }
    public var Notifications_DisplayNamesOnLockScreen: String { return self._s[729]! }
    public var Calls_NoMissedCallsPlacehoder: String { return self._s[730]! }
    public var Notifications_ExceptionsDefaultSound: String { return self._s[731]! }
    public func PUSH_CHANNEL_MESSAGE_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[732]!, self._r[732]!, [_1])
    }
    public func DialogList_SearchSubtitleFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[733]!, self._r[733]!, [_1, _2])
    }
    public func Channel_AdminLog_MessageRemovedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[734]!, self._r[734]!, [_0])
    }
    public var GroupPermission_Delete: String { return self._s[735]! }
    public var Passport_Language_uk: String { return self._s[736]! }
    public var StickerPack_HideStickers: String { return self._s[738]! }
    public var ChangePhoneNumberNumber_NumberPlaceholder: String { return self._s[739]! }
    public func PUSH_CHAT_MESSAGE_PHOTO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[740]!, self._r[740]!, [_1, _2])
    }
    public var Activity_UploadingVideoMessage: String { return self._s[741]! }
    public func GroupPermission_ApplyAlertText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[742]!, self._r[742]!, [_0])
    }
    public var Channel_TitleInfo: String { return self._s[743]! }
    public var StickerPacksSettings_ArchivedPacks_Info: String { return self._s[744]! }
    public var Settings_CallSettings: String { return self._s[745]! }
    public var Camera_SquareMode: String { return self._s[746]! }
    public var GroupInfo_SharedMediaNone: String { return self._s[747]! }
    public func PUSH_MESSAGE_VIDEO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[748]!, self._r[748]!, [_1])
    }
    public var Bot_GenericBotStatus: String { return self._s[749]! }
    public var Application_Update: String { return self._s[751]! }
    public var Month_ShortJanuary: String { return self._s[752]! }
    public var Contacts_PermissionsKeepDisabled: String { return self._s[753]! }
    public var Channel_AdminLog_BanReadMessages: String { return self._s[754]! }
    public var Settings_AppLanguage_Unofficial: String { return self._s[755]! }
    public var Passport_Address_Street2Placeholder: String { return self._s[756]! }
    public func Map_LiveLocationShortHour(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[757]!, self._r[757]!, [_0])
    }
    public var NetworkUsageSettings_Cellular: String { return self._s[758]! }
    public var Appearance_PreviewOutgoingText: String { return self._s[759]! }
    public var Notifications_PermissionsAllowInSettings: String { return self._s[760]! }
    public var Map_Directions: String { return self._s[762]! }
    public var Passport_FieldIdentityTranslationHelp: String { return self._s[764]! }
    public var Appearance_ThemeDay: String { return self._s[765]! }
    public var Passport_Identity_AddPassport: String { return self._s[767]! }
    public var Call_Message: String { return self._s[768]! }
    public var PhotoEditor_ExposureTool: String { return self._s[769]! }
    public var Passport_FieldOneOf_Delimeter: String { return self._s[771]! }
    public var Channel_AdminLog_CanBanUsers: String { return self._s[773]! }
    public var Appearance_Preview: String { return self._s[774]! }
    public var Compose_ChannelMembers: String { return self._s[775]! }
    public var Conversation_DeleteManyMessages: String { return self._s[776]! }
    public var ReportPeer_ReasonOther_Title: String { return self._s[777]! }
    public var Checkout_ErrorProviderAccountTimeout: String { return self._s[778]! }
    public var TwoStepAuth_ResetAccountConfirmation: String { return self._s[779]! }
    public var Channel_Stickers_CreateYourOwn: String { return self._s[782]! }
    public var Conversation_UpdateTelegram: String { return self._s[783]! }
    public func Notification_PinnedPhotoMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[784]!, self._r[784]!, [_0])
    }
    public func PUSH_PINNED_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[785]!, self._r[785]!, [_1])
    }
    public var GroupInfo_Administrators_Title: String { return self._s[786]! }
    public func PrivacySettings_LastSeenNobodyPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[787]!, self._r[787]!, [_0])
    }
    public var Tour_Title3: String { return self._s[788]! }
    public var Channel_EditAdmin_PermissionInviteSubscribers: String { return self._s[789]! }
    public var Clipboard_SendPhoto: String { return self._s[793]! }
    public var MediaPicker_Videos: String { return self._s[794]! }
    public var Passport_Email_Title: String { return self._s[795]! }
    public func PrivacySettings_LastSeenEverybodyMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[796]!, self._r[796]!, [_0])
    }
    public var StickerPacksSettings_Title: String { return self._s[797]! }
    public var Conversation_MessageDialogDelete: String { return self._s[798]! }
    public var Privacy_Calls_CustomHelp: String { return self._s[800]! }
    public var Message_Wallpaper: String { return self._s[801]! }
    public var GroupInfo_SetSound: String { return self._s[802]! }
    public var Core_ServiceUserStatus: String { return self._s[803]! }
    public var LiveLocationUpdated_JustNow: String { return self._s[804]! }
    public var Call_StatusFailed: String { return self._s[805]! }
    public var TwoStepAuth_SetupPasswordDescription: String { return self._s[806]! }
    public var TwoStepAuth_SetPassword: String { return self._s[807]! }
    public func SocksProxySetup_ProxyStatusPing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[809]!, self._r[809]!, [_0])
    }
    public var Calls_SubmitRating: String { return self._s[810]! }
    public var Profile_Username: String { return self._s[811]! }
    public var Bot_DescriptionTitle: String { return self._s[812]! }
    public var MaskStickerSettings_Title: String { return self._s[813]! }
    public var SharedMedia_CategoryOther: String { return self._s[814]! }
    public var GroupInfo_SetGroupPhoto: String { return self._s[815]! }
    public var Common_NotNow: String { return self._s[816]! }
    public var CallFeedback_IncludeLogsInfo: String { return self._s[817]! }
    public var Map_Location: String { return self._s[818]! }
    public var Invitation_JoinGroup: String { return self._s[819]! }
    public var AutoDownloadSettings_Title: String { return self._s[821]! }
    public var Conversation_DiscardVoiceMessageDescription: String { return self._s[822]! }
    public var Channel_ErrorAddBlocked: String { return self._s[823]! }
    public var Conversation_UnblockUser: String { return self._s[824]! }
    public var Watch_Bot_Restart: String { return self._s[825]! }
    public var TwoStepAuth_Title: String { return self._s[826]! }
    public var Channel_AdminLog_BanSendMessages: String { return self._s[827]! }
    public var Checkout_ShippingMethod: String { return self._s[828]! }
    public var Passport_Identity_OneOfTypeIdentityCard: String { return self._s[829]! }
    public func PUSH_CHAT_MESSAGE_STICKER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[830]!, self._r[830]!, [_1, _2, _3])
    }
    public func Channel_Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[832]!, self._r[832]!, [_0])
    }
    public var AuthSessions_TerminateOtherSessions: String { return self._s[833]! }
    public var Contacts_FailedToSendInvitesMessage: String { return self._s[834]! }
    public var PrivacySettings_TwoStepAuth: String { return self._s[835]! }
    public var Conversation_EditingMessagePanelMedia: String { return self._s[836]! }
    public var Checkout_PaymentMethod_Title: String { return self._s[837]! }
    public var SocksProxySetup_Connection: String { return self._s[838]! }
    public var Group_MessagePhotoRemoved: String { return self._s[839]! }
    public var Channel_Stickers_NotFound: String { return self._s[841]! }
    public var Group_About_Help: String { return self._s[842]! }
    public var Notification_PassportValueProofOfIdentity: String { return self._s[843]! }
    public func ApplyLanguage_ChangeLanguageOfficialText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[845]!, self._r[845]!, [_1])
    }
    public var CheckoutInfo_ShippingInfoStatePlaceholder: String { return self._s[847]! }
    public var Notifications_GroupNotificationsExceptionsHelp: String { return self._s[848]! }
    public var SocksProxySetup_Password: String { return self._s[849]! }
    public var Notifications_PermissionsEnable: String { return self._s[850]! }
    public var TwoStepAuth_ChangeEmail: String { return self._s[852]! }
    public func Channel_AdminLog_MessageInvitedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[853]!, self._r[853]!, [_1])
    }
    public func Time_MonthOfYear_m10(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[855]!, self._r[855]!, [_0])
    }
    public var Passport_Identity_TypeDriversLicense: String { return self._s[856]! }
    public var ArchivedPacksAlert_Title: String { return self._s[857]! }
    public func Time_PreciseDate_m7(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[858]!, self._r[858]!, [_1, _2, _3])
    }
    public var PrivacyLastSeenSettings_GroupsAndChannelsHelp: String { return self._s[859]! }
    public var Privacy_Calls_NeverAllow_Placeholder: String { return self._s[861]! }
    public var Conversation_StatusTyping: String { return self._s[862]! }
    public var Broadcast_AdminLog_EmptyText: String { return self._s[863]! }
    public var Notification_PassportValueProofOfAddress: String { return self._s[864]! }
    public var UserInfo_CreateNewContact: String { return self._s[865]! }
    public var Passport_Identity_FrontSide: String { return self._s[866]! }
    public var Calls_CallTabTitle: String { return self._s[867]! }
    public var Channel_AdminLog_ChannelEmptyText: String { return self._s[868]! }
    public func Login_BannedPhoneBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[869]!, self._r[869]!, [_0])
    }
    public var Watch_UserInfo_MuteTitle: String { return self._s[870]! }
    public var SharedMedia_EmptyMusicText: String { return self._s[871]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1minute: String { return self._s[872]! }
    public var Paint_Stickers: String { return self._s[873]! }
    public var Privacy_GroupsAndChannels: String { return self._s[874]! }
    public var UserInfo_AddContact: String { return self._s[876]! }
    public func Conversation_MessageViaUser(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[877]!, self._r[877]!, [_0])
    }
    public var PhoneNumberHelp_ChangeNumber: String { return self._s[879]! }
    public var DialogList_NoMessagesTitle: String { return self._s[881]! }
    public var EditProfile_NameAndPhotoHelp: String { return self._s[882]! }
    public var BlockedUsers_BlockUser: String { return self._s[883]! }
    public var Notifications_PermissionsOpenSettings: String { return self._s[884]! }
    public var MediaPicker_UngroupDescription: String { return self._s[885]! }
    public var Watch_NoConnection: String { return self._s[886]! }
    public var Month_GenSeptember: String { return self._s[887]! }
    public var Conversation_ViewGroup: String { return self._s[888]! }
    public var Channel_AdminLogFilter_EventsLeavingSubscribers: String { return self._s[891]! }
    public var Passport_FieldOneOf_FinalDelimeter: String { return self._s[892]! }
    public var MediaPicker_CameraRoll: String { return self._s[894]! }
    public var Month_GenAugust: String { return self._s[895]! }
    public var AccessDenied_VideoMessageMicrophone: String { return self._s[896]! }
    public var SharedMedia_EmptyText: String { return self._s[897]! }
    public var Map_ShareLiveLocation: String { return self._s[898]! }
    public var Calls_All: String { return self._s[899]! }
    public var Appearance_ThemeNight: String { return self._s[902]! }
    public var Conversation_HoldForAudio: String { return self._s[903]! }
    public var GroupInfo_GroupHistoryHidden: String { return self._s[906]! }
    public var SocksProxySetup_Secret: String { return self._s[907]! }
    public var Channel_BanList_RestrictedTitle: String { return self._s[909]! }
    public var Conversation_Location: String { return self._s[910]! }
    public var ChatSettings_AutoDownloadPhotos: String { return self._s[912]! }
    public var Notifications_PermissionsText: String { return self._s[913]! }
    public var SocksProxySetup_ProxyStatusConnecting: String { return self._s[914]! }
    public var Channel_EditAdmin_PermissionPinMessages: String { return self._s[916]! }
    public var TwoStepAuth_ReEnterPasswordDescription: String { return self._s[918]! }
    public var Passport_DeletePassportConfirmation: String { return self._s[920]! }
    public var Login_InvalidCodeError: String { return self._s[921]! }
    public var StickerPacksSettings_FeaturedPacks: String { return self._s[922]! }
    public func ChatList_DeleteSecretChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[923]!, self._r[923]!, [_0])
    }
    public func GroupInfo_InvitationLinkAcceptChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[924]!, self._r[924]!, [_0])
    }
    public var Call_CallInProgressTitle: String { return self._s[925]! }
    public var Month_ShortSeptember: String { return self._s[926]! }
    public var Watch_ChannelInfo_Title: String { return self._s[927]! }
    public var DialogList_PasscodeLockHelp: String { return self._s[930]! }
    public var Notifications_Badge_IncludePublicGroups: String { return self._s[931]! }
    public var Channel_AdminLogFilter_EventsTitle: String { return self._s[932]! }
    public var PhotoEditor_CropReset: String { return self._s[933]! }
    public var Group_Username_CreatePrivateLinkHelp: String { return self._s[935]! }
    public var Channel_Management_LabelEditor: String { return self._s[936]! }
    public var Passport_Identity_LatinNameHelp: String { return self._s[938]! }
    public var PhotoEditor_HighlightsTool: String { return self._s[939]! }
    public var UserInfo_Title: String { return self._s[940]! }
    public var AccessDenied_Title: String { return self._s[941]! }
    public var DialogList_SearchLabel: String { return self._s[942]! }
    public var Group_Setup_HistoryHidden: String { return self._s[943]! }
    public var TwoStepAuth_PasswordChangeSuccess: String { return self._s[944]! }
    public var State_Updating: String { return self._s[946]! }
    public var Contacts_TabTitle: String { return self._s[947]! }
    public var Notifications_Badge_CountUnreadMessages: String { return self._s[949]! }
    public var GroupInfo_GroupHistory: String { return self._s[950]! }
    public var Conversation_UnsupportedMediaPlaceholder: String { return self._s[951]! }
    public var Wallpaper_SetColor: String { return self._s[952]! }
    public var CheckoutInfo_ShippingInfoCountry: String { return self._s[953]! }
    public var Passport_Identity_OneOfTypeDriversLicense: String { return self._s[954]! }
    public var Contacts_NotRegisteredSection: String { return self._s[955]! }
    public func Time_PreciseDate_m4(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[956]!, self._r[956]!, [_1, _2, _3])
    }
    public var Paint_Clear: String { return self._s[957]! }
    public var StickerPacksSettings_ArchivedMasks: String { return self._s[958]! }
    public var SocksProxySetup_Connecting: String { return self._s[959]! }
    public var ExplicitContent_AlertChannel: String { return self._s[960]! }
    public var CreatePoll_AllOptionsAdded: String { return self._s[961]! }
    public var Conversation_Contact: String { return self._s[962]! }
    public var Login_CodeExpired: String { return self._s[963]! }
    public var Passport_DiscardMessageAction: String { return self._s[964]! }
    public var Channel_AdminLog_MessagePreviousDescription: String { return self._s[965]! }
    public var Channel_AdminLog_EmptyMessageText: String { return self._s[966]! }
    public var Month_ShortApril: String { return self._s[967]! }
    public var AuthSessions_CurrentSession: String { return self._s[968]! }
    public var WallpaperPreview_CropTopText: String { return self._s[972]! }
    public var PrivacySettings_DeleteAccountIfAwayFor: String { return self._s[973]! }
    public var CheckoutInfo_ShippingInfoTitle: String { return self._s[974]! }
    public var Channel_Setup_TypePrivate: String { return self._s[976]! }
    public var Forward_ChannelReadOnly: String { return self._s[979]! }
    public var PhotoEditor_CurvesBlue: String { return self._s[980]! }
    public var UserInfo_BotPrivacy: String { return self._s[981]! }
    public var Notification_PassportValueEmail: String { return self._s[982]! }
    public var EmptyGroupInfo_Subtitle: String { return self._s[983]! }
    public var GroupPermission_NewTitle: String { return self._s[984]! }
    public var CallFeedback_ReasonDropped: String { return self._s[985]! }
    public var GroupInfo_Permissions_AddException: String { return self._s[986]! }
    public var Channel_SignMessages_Help: String { return self._s[988]! }
    public var Undo_ChatDeleted: String { return self._s[990]! }
    public var Conversation_ChatBackground: String { return self._s[991]! }
    public var ChannelMembers_WhoCanAddMembers_Admins: String { return self._s[992]! }
    public var FastTwoStepSetup_EmailPlaceholder: String { return self._s[993]! }
    public var Passport_Language_pt: String { return self._s[994]! }
    public var NotificationsSound_Popcorn: String { return self._s[997]! }
    public var AutoNightTheme_Disabled: String { return self._s[998]! }
    public var BlockedUsers_LeavePrefix: String { return self._s[999]! }
    public var WallpaperPreview_CustomColorTopText: String { return self._s[1000]! }
    public var Contacts_PermissionsSuppressWarningText: String { return self._s[1001]! }
    public var WallpaperSearch_ColorBlue: String { return self._s[1002]! }
    public func CancelResetAccount_TextSMS(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1003]!, self._r[1003]!, [_0])
    }
    public var CheckoutInfo_ErrorNameInvalid: String { return self._s[1004]! }
    public var SocksProxySetup_UseForCalls: String { return self._s[1005]! }
    public var Passport_DeleteDocumentConfirmation: String { return self._s[1007]! }
    public func Conversation_Megabytes(_ _0: Float) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1008]!, self._r[1008]!, ["\(_0)"])
    }
    public var SocksProxySetup_Hostname: String { return self._s[1010]! }
    public var Compose_NewEncryptedChat: String { return self._s[1011]! }
    public var Login_CodeFloodError: String { return self._s[1012]! }
    public var Calls_TabTitle: String { return self._s[1013]! }
    public var Passport_Language_he: String { return self._s[1014]! }
    public var GroupPermission_Title: String { return self._s[1015]! }
    public func Channel_AdminLog_MessageGroupPreHistoryHidden(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1016]!, self._r[1016]!, [_0])
    }
    public var GroupPermission_NoChangeInfo: String { return self._s[1017]! }
    public var Tour_Text1: String { return self._s[1018]! }
    public var Month_ShortFebruary: String { return self._s[1019]! }
    public var TwoStepAuth_EmailSkip: String { return self._s[1020]! }
    public var NotificationsSound_Glass: String { return self._s[1021]! }
    public var Appearance_ThemeNightBlue: String { return self._s[1022]! }
    public var CheckoutInfo_Pay: String { return self._s[1023]! }
    public var Invite_LargeRecipientsCountWarning: String { return self._s[1025]! }
    public var Call_CallAgain: String { return self._s[1027]! }
    public var AttachmentMenu_SendAsFile: String { return self._s[1028]! }
    public var Watch_Message_Game: String { return self._s[1029]! }
    public var AccessDenied_MicrophoneRestricted: String { return self._s[1030]! }
    public var Passport_InvalidPasswordError: String { return self._s[1031]! }
    public var Stickers_Install: String { return self._s[1032]! }
    public var PrivacyLastSeenSettings_NeverShareWith: String { return self._s[1033]! }
    public var Passport_Identity_ResidenceCountry: String { return self._s[1035]! }
    public var Notifications_GroupNotificationsHelp: String { return self._s[1036]! }
    public var AuthSessions_OtherSessions: String { return self._s[1037]! }
    public var Channel_Username_Help: String { return self._s[1038]! }
    public var Camera_Title: String { return self._s[1039]! }
    public var GroupInfo_SetGroupPhotoDelete: String { return self._s[1041]! }
    public var Channel_AdminLog_SendPolls: String { return self._s[1042]! }
    public var Channel_AdminLog_TitleAllEvents: String { return self._s[1043]! }
    public var Channel_EditAdmin_PermissionInviteMembers: String { return self._s[1044]! }
    public var Contacts_MemberSearchSectionTitleGroup: String { return self._s[1045]! }
    public var Conversation_RestrictedStickers: String { return self._s[1046]! }
    public var Notifications_ExceptionsResetToDefaults: String { return self._s[1048]! }
    public var UserInfo_TelegramCall: String { return self._s[1050]! }
    public var TwoStepAuth_SetupResendEmailCode: String { return self._s[1051]! }
    public var CreatePoll_OptionsHeader: String { return self._s[1052]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Title: String { return self._s[1053]! }
    public var Passport_Identity_EditPersonalDetails: String { return self._s[1054]! }
    public func Time_PreciseDate_m1(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1055]!, self._r[1055]!, [_1, _2, _3])
    }
    public var Settings_SaveEditedPhotos: String { return self._s[1056]! }
    public var TwoStepAuth_ConfirmationTitle: String { return self._s[1057]! }
    public var Privacy_GroupsAndChannels_NeverAllow_Title: String { return self._s[1058]! }
    public var Conversation_MessageDialogRetry: String { return self._s[1059]! }
    public var Conversation_DiscardVoiceMessageAction: String { return self._s[1060]! }
    public var Group_Setup_TypeHeader: String { return self._s[1061]! }
    public var Paint_RecentStickers: String { return self._s[1062]! }
    public var PhotoEditor_GrainTool: String { return self._s[1063]! }
    public var CheckoutInfo_ShippingInfoState: String { return self._s[1064]! }
    public var EmptyGroupInfo_Line4: String { return self._s[1065]! }
    public var Watch_AuthRequired: String { return self._s[1067]! }
    public func Passport_Email_UseTelegramEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1068]!, self._r[1068]!, [_0])
    }
    public var Conversation_EncryptedDescriptionTitle: String { return self._s[1069]! }
    public var ChannelIntro_Text: String { return self._s[1070]! }
    public var DialogList_DeleteBotConfirmation: String { return self._s[1071]! }
    public var GroupPermission_NoSendMedia: String { return self._s[1072]! }
    public var Calls_AddTab: String { return self._s[1073]! }
    public var Message_ReplyActionButtonShowReceipt: String { return self._s[1074]! }
    public var Channel_AdminLog_EmptyFilterText: String { return self._s[1075]! }
    public var Notification_MessageLifetime1d: String { return self._s[1076]! }
    public var Notifications_ChannelNotificationsExceptionsHelp: String { return self._s[1077]! }
    public var Channel_BanUser_PermissionsHeader: String { return self._s[1078]! }
    public var Passport_Identity_GenderFemale: String { return self._s[1079]! }
    public var BlockedUsers_BlockTitle: String { return self._s[1080]! }
    public func PUSH_CHANNEL_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1081]!, self._r[1081]!, [_1])
    }
    public var Weekday_Yesterday: String { return self._s[1082]! }
    public var WallpaperSearch_ColorBlack: String { return self._s[1083]! }
    public var AutoNightTheme_Scheduled: String { return self._s[1084]! }
    public func Login_PhoneGenericEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String, _ _6: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1085]!, self._r[1085]!, [_1, _2, _3, _4, _5, _6])
    }
    public var PrivacyPolicy_DeclineDeleteNow: String { return self._s[1086]! }
    public func PUSH_CHAT_JOINED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1087]!, self._r[1087]!, [_1, _2])
    }
    public var CreatePoll_Create: String { return self._s[1088]! }
    public var Channel_Members_AddBannedErrorAdmin: String { return self._s[1089]! }
    public func Notification_CallFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1090]!, self._r[1090]!, [_1, _2])
    }
    public var Checkout_ErrorProviderAccountInvalid: String { return self._s[1091]! }
    public var Notifications_InAppNotificationsSounds: String { return self._s[1093]! }
    public var Preview_OpenInInstagram: String { return self._s[1094]! }
    public var Notification_MessageLifetimeRemovedOutgoing: String { return self._s[1095]! }
    public func PUSH_CHAT_ADD_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1096]!, self._r[1096]!, [_1, _2, _3])
    }
    public func Passport_PrivacyPolicy(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1097]!, self._r[1097]!, [_1, _2])
    }
    public var Channel_AdminLog_InfoPanelAlertTitle: String { return self._s[1098]! }
    public var NetworkUsageSettings_TotalSection: String { return self._s[1099]! }
    public var Channel_Setup_TypePrivateHelp: String { return self._s[1100]! }
    public func PUSH_CHAT_MESSAGE_POLL(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1101]!, self._r[1101]!, [_1, _2])
    }
    public var Privacy_GroupsAndChannels_NeverAllow_Placeholder: String { return self._s[1103]! }
    public var FastTwoStepSetup_HintSection: String { return self._s[1104]! }
    public var Wallpaper_PhotoLibrary: String { return self._s[1105]! }
    public var TwoStepAuth_SetupResendEmailCodeAlert: String { return self._s[1106]! }
    public var Watch_LastSeen_WithinAMonth: String { return self._s[1107]! }
    public var GroupInfo_ActionPromote: String { return self._s[1108]! }
    public var PasscodeSettings_SimplePasscode: String { return self._s[1109]! }
    public var GroupInfo_Permissions_Title: String { return self._s[1110]! }
    public var Permissions_ContactsText_v0: String { return self._s[1111]! }
    public var PrivacySettings_DataSettingsHelp: String { return self._s[1114]! }
    public var Passport_FieldEmailHelp: String { return self._s[1115]! }
    public var Passport_Identity_GenderPlaceholder: String { return self._s[1116]! }
    public var Weekday_ShortSaturday: String { return self._s[1117]! }
    public var ContactInfo_PhoneLabelMain: String { return self._s[1118]! }
    public var Watch_Conversation_UserInfo: String { return self._s[1119]! }
    public var CheckoutInfo_ShippingInfoCityPlaceholder: String { return self._s[1120]! }
    public var PrivacyLastSeenSettings_Title: String { return self._s[1121]! }
    public var Conversation_ShareBotLocationConfirmation: String { return self._s[1122]! }
    public var PhotoEditor_VignetteTool: String { return self._s[1123]! }
    public var Passport_Address_Street1Placeholder: String { return self._s[1124]! }
    public var Passport_Language_et: String { return self._s[1125]! }
    public var Passport_Language_bg: String { return self._s[1127]! }
    public var Stickers_NoStickersFound: String { return self._s[1129]! }
    public func PUSH_CHANNEL_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1131]!, self._r[1131]!, [_1, _2])
    }
    public var Settings_About: String { return self._s[1132]! }
    public func Channel_AdminLog_MessageRestricted(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1133]!, self._r[1133]!, [_0, _1, _2])
    }
    public var KeyCommand_NewMessage: String { return self._s[1135]! }
    public var Group_ErrorAddBlocked: String { return self._s[1136]! }
    public func Message_PaymentSent(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1137]!, self._r[1137]!, [_0])
    }
    public var Map_LocationTitle: String { return self._s[1138]! }
    public var CallSettings_UseLessDataLongDescription: String { return self._s[1139]! }
    public var Cache_ClearProgress: String { return self._s[1140]! }
    public func Channel_Management_ErrorNotMember(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1141]!, self._r[1141]!, [_0])
    }
    public var GroupRemoved_AddToGroup: String { return self._s[1142]! }
    public var Passport_UpdateRequiredError: String { return self._s[1143]! }
    public func PUSH_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1144]!, self._r[1144]!, [_1])
    }
    public var Notifications_PermissionsSuppressWarningText: String { return self._s[1146]! }
    public var Passport_Identity_MainPageHelp: String { return self._s[1147]! }
    public var Conversation_StatusKickedFromGroup: String { return self._s[1148]! }
    public var Passport_Language_ka: String { return self._s[1149]! }
    public var Call_Decline: String { return self._s[1150]! }
    public var SocksProxySetup_ProxyEnabled: String { return self._s[1151]! }
    public func AuthCode_Alert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1154]!, self._r[1154]!, [_0])
    }
    public var CallFeedback_Send: String { return self._s[1155]! }
    public func Channel_AdminLog_MessagePromotedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1156]!, self._r[1156]!, [_1, _2])
    }
    public var Passport_Phone_UseTelegramNumberHelp: String { return self._s[1157]! }
    public var Passport_DeletePassport: String { return self._s[1159]! }
    public var Privacy_Calls_P2PAlways: String { return self._s[1160]! }
    public var Month_ShortDecember: String { return self._s[1161]! }
    public var Channel_AdminLog_CanEditMessages: String { return self._s[1163]! }
    public func Contacts_AccessDeniedHelpLandscape(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1164]!, self._r[1164]!, [_0])
    }
    public var Channel_Stickers_Searching: String { return self._s[1165]! }
    public var Conversation_EncryptedDescription1: String { return self._s[1166]! }
    public var Conversation_EncryptedDescription2: String { return self._s[1167]! }
    public var Conversation_EncryptedDescription3: String { return self._s[1168]! }
    public var PhotoEditor_SharpenTool: String { return self._s[1169]! }
    public var Conversation_EncryptedDescription4: String { return self._s[1171]! }
    public var Channel_Members_AddMembers: String { return self._s[1172]! }
    public var Wallpaper_Search: String { return self._s[1173]! }
    public var Weekday_Friday: String { return self._s[1174]! }
    public var Privacy_ContactsSync: String { return self._s[1175]! }
    public var ApplyLanguage_ChangeLanguageAction: String { return self._s[1176]! }
    public func Channel_Management_RestrictedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1177]!, self._r[1177]!, [_0])
    }
    public var GroupInfo_Permissions_Removed: String { return self._s[1178]! }
    public var Passport_Identity_GenderMale: String { return self._s[1179]! }
    public func Call_StatusBar(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1180]!, self._r[1180]!, [_0])
    }
    public var Notifications_PermissionsKeepDisabled: String { return self._s[1181]! }
    public var Conversation_JumpToDate: String { return self._s[1182]! }
    public var Contacts_GlobalSearch: String { return self._s[1183]! }
    public var AutoDownloadSettings_ResetHelp: String { return self._s[1184]! }
    public var Profile_MessageLifetime1d: String { return self._s[1185]! }
    public func MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1186]!, self._r[1186]!, [_1, _2])
    }
    public var StickerPack_BuiltinPackName: String { return self._s[1189]! }
    public func PUSH_CHAT_MESSAGE_AUDIO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1190]!, self._r[1190]!, [_1, _2])
    }
    public var Passport_InfoTitle: String { return self._s[1192]! }
    public var Notifications_PermissionsUnreachableText: String { return self._s[1193]! }
    public func NetworkUsageSettings_CellularUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1197]!, self._r[1197]!, [_0])
    }
    public func PUSH_CHAT_MESSAGE_GEO(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1198]!, self._r[1198]!, [_1, _2])
    }
    public var Passport_Address_TypePassportRegistrationUploadScan: String { return self._s[1199]! }
    public var Profile_BotInfo: String { return self._s[1200]! }
    public var Watch_Compose_CreateMessage: String { return self._s[1201]! }
    public var Month_ShortNovember: String { return self._s[1202]! }
    public var Wallpaper_SetCustomBackground: String { return self._s[1203]! }
    public var Passport_Identity_TranslationsHelp: String { return self._s[1204]! }
    public var NotificationsSound_Chime: String { return self._s[1205]! }
    public var Passport_Language_ko: String { return self._s[1207]! }
    public var InviteText_URL: String { return self._s[1208]! }
    public var TextFormat_Monospace: String { return self._s[1209]! }
    public func Time_PreciseDate_m11(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1210]!, self._r[1210]!, [_1, _2, _3])
    }
    public func Login_WillSendSms(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1211]!, self._r[1211]!, [_0])
    }
    public func Watch_Time_ShortWeekdayAt(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1212]!, self._r[1212]!, [_1, _2])
    }
    public var Passport_InfoLearnMore: String { return self._s[1214]! }
    public var TwoStepAuth_EmailPlaceholder: String { return self._s[1215]! }
    public var Passport_Identity_AddIdentityCard: String { return self._s[1216]! }
    public var Your_card_has_expired: String { return self._s[1217]! }
    public var StickerPacksSettings_StickerPacksSection: String { return self._s[1218]! }
    public var GroupInfo_InviteLink_Help: String { return self._s[1219]! }
    public var Conversation_Report: String { return self._s[1222]! }
    public var Notifications_MessageNotificationsSound: String { return self._s[1223]! }
    public var Notification_MessageLifetime1m: String { return self._s[1224]! }
    public var Privacy_ContactsTitle: String { return self._s[1225]! }
    public var Conversation_ShareMyContactInfo: String { return self._s[1226]! }
    public var ChannelMembers_WhoCanAddMembersAdminsHelp: String { return self._s[1227]! }
    public var Channel_Members_Title: String { return self._s[1228]! }
    public var Map_OpenInWaze: String { return self._s[1229]! }
    public var Login_PhoneBannedError: String { return self._s[1230]! }
    public func LiveLocationUpdated_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1231]!, self._r[1231]!, [_0])
    }
    public var Group_Management_AddModeratorHelp: String { return self._s[1232]! }
    public var Common_OK: String { return self._s[1233]! }
    public var Passport_Address_TypeBankStatementUploadScan: String { return self._s[1234]! }
    public var Cache_Music: String { return self._s[1235]! }
    public var PasscodeSettings_UnlockWithTouchId: String { return self._s[1236]! }
    public var TwoStepAuth_HintPlaceholder: String { return self._s[1237]! }
    public func PUSH_PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1238]!, self._r[1238]!, [_1])
    }
    public func Passport_RequestHeader(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1239]!, self._r[1239]!, [_0])
    }
    public var Watch_MessageView_ViewOnPhone: String { return self._s[1241]! }
    public var Privacy_Calls_CustomShareHelp: String { return self._s[1242]! }
    public var ChangePhoneNumberNumber_Title: String { return self._s[1244]! }
    public var State_ConnectingToProxyInfo: String { return self._s[1245]! }
    public var Message_VideoMessage: String { return self._s[1247]! }
    public var ChannelInfo_DeleteChannel: String { return self._s[1248]! }
    public var ContactInfo_PhoneLabelOther: String { return self._s[1249]! }
    public var Channel_EditAdmin_CannotEdit: String { return self._s[1250]! }
    public var Passport_DeleteAddressConfirmation: String { return self._s[1251]! }
    public var WallpaperPreview_SwipeBottomText: String { return self._s[1252]! }
    public var Activity_RecordingAudio: String { return self._s[1253]! }
    public var PasscodeSettings_TryAgainIn1Minute: String { return self._s[1254]! }
    public func Notification_ChangedGroupName(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1256]!, self._r[1256]!, [_0, _1])
    }
    public func EmptyGroupInfo_Line1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1259]!, self._r[1259]!, [_0])
    }
    public var Conversation_ApplyLocalization: String { return self._s[1260]! }
    public var UserInfo_AddPhone: String { return self._s[1261]! }
    public var Map_ShareLiveLocationHelp: String { return self._s[1262]! }
    public func Passport_Identity_NativeNameGenericHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1263]!, self._r[1263]!, [_0])
    }
    public var Passport_Scans: String { return self._s[1265]! }
    public var BlockedUsers_Unblock: String { return self._s[1266]! }
    public func PUSH_ENCRYPTION_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1267]!, self._r[1267]!, [_1])
    }
    public var Channel_Management_LabelCreator: String { return self._s[1268]! }
    public var Passport_Identity_NativeNameGenericTitle: String { return self._s[1269]! }
    public func Login_EmailPhoneBody(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1270]!, self._r[1270]!, [_0, _1, _2])
    }
    public var Login_PhoneNumberHelp: String { return self._s[1271]! }
    public var LastSeen_ALongTimeAgo: String { return self._s[1272]! }
    public var Channel_AdminLog_CanPinMessages: String { return self._s[1273]! }
    public var ChannelIntro_CreateChannel: String { return self._s[1274]! }
    public var Conversation_UnreadMessages: String { return self._s[1275]! }
    public var Channel_AdminLog_EmptyText: String { return self._s[1276]! }
    public var Notification_GroupActivated: String { return self._s[1277]! }
    public var NotificationSettings_ContactJoinedInfo: String { return self._s[1278]! }
    public func Notification_PinnedContactMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1279]!, self._r[1279]!, [_0])
    }
    public func DownloadingStatus(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1280]!, self._r[1280]!, [_0, _1])
    }
    public var GroupInfo_ConvertToSupergroup: String { return self._s[1282]! }
    public func PrivacyPolicy_AgeVerificationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1283]!, self._r[1283]!, [_0])
    }
    public var Undo_DeletedChannel: String { return self._s[1284]! }
    public var CallFeedback_AddComment: String { return self._s[1285]! }
    public var Document_TargetConfirmationFormat: String { return self._s[1286]! }
    public func Call_StatusOngoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1287]!, self._r[1287]!, [_0])
    }
    public var Contacts_SortByName: String { return self._s[1288]! }
    public func CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1290]!, self._r[1290]!, [_1, _2, _3])
    }
    public var Conversation_ClearSelfHistory: String { return self._s[1291]! }
    public var Checkout_NewCard_PostcodePlaceholder: String { return self._s[1292]! }
    public var Stickers_SuggestNone: String { return self._s[1293]! }
    public var ChatSettings_Cache: String { return self._s[1294]! }
    public var Settings_SaveIncomingPhotos: String { return self._s[1295]! }
    public var Media_ShareThisPhoto: String { return self._s[1296]! }
    public var InfoPlist_NSContactsUsageDescription: String { return self._s[1297]! }
    public var Conversation_ContextMenuCopyLink: String { return self._s[1298]! }
    public var PrivacyPolicy_AgeVerificationTitle: String { return self._s[1299]! }
    public var TwoStepAuth_SetupPasswordEnterPasswordNew: String { return self._s[1300]! }
    public var Permissions_CellularDataTitle_v0: String { return self._s[1301]! }
    public var WallpaperSearch_ColorWhite: String { return self._s[1303]! }
    public var Channel_AdminLog_DefaultRestrictionsUpdated: String { return self._s[1304]! }
    public var Map_OpenIn: String { return self._s[1305]! }
    public func PUSH_PHONE_CALL_MISSED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1308]!, self._r[1308]!, [_1])
    }
    public func ChannelInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1309]!, self._r[1309]!, [_0])
    }
    public var MessagePoll_LabelClosed: String { return self._s[1310]! }
    public var Passport_Identity_MiddleNamePlaceholder: String { return self._s[1312]! }
    public var UserInfo_FirstNamePlaceholder: String { return self._s[1313]! }
    public var PrivacyLastSeenSettings_WhoCanSeeMyTimestamp: String { return self._s[1314]! }
    public var Login_SelectCountry_Title: String { return self._s[1315]! }
    public var Channel_EditAdmin_PermissionBanUsers: String { return self._s[1316]! }
    public var Channel_AdminLog_ChangeInfo: String { return self._s[1317]! }
    public var Watch_Suggestion_BRB: String { return self._s[1318]! }
    public var Passport_Identity_EditIdentityCard: String { return self._s[1319]! }
    public var Contacts_PermissionsTitle: String { return self._s[1320]! }
    public var Conversation_RestrictedInline: String { return self._s[1321]! }
    public var StickerPack_ViewPack: String { return self._s[1323]! }
    public func Update_AppVersion(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1324]!, self._r[1324]!, [_0])
    }
    public var Compose_NewChannel: String { return self._s[1326]! }
    public var Channel_Info_Stickers: String { return self._s[1330]! }
    public var AutoNightTheme_PreferredTheme: String { return self._s[1331]! }
    public var PrivacyPolicy_AgeVerificationAgree: String { return self._s[1332]! }
    public var Passport_DeletePersonalDetails: String { return self._s[1333]! }
    public var Conversation_SearchNoResults: String { return self._s[1335]! }
    public var MessagePoll_LabelAnonymous: String { return self._s[1336]! }
    public var Channel_Members_AddAdminErrorNotAMember: String { return self._s[1337]! }
    public var Login_Code: String { return self._s[1338]! }
    public var Watch_Suggestion_WhatsUp: String { return self._s[1339]! }
    public var Weekday_ShortThursday: String { return self._s[1340]! }
    public var Resolve_ErrorNotFound: String { return self._s[1342]! }
    public var LastSeen_Offline: String { return self._s[1343]! }
    public var Privacy_Calls_AlwaysAllow_Title: String { return self._s[1344]! }
    public var GroupInfo_Title: String { return self._s[1345]! }
    public var NotificationsSound_Note: String { return self._s[1346]! }
    public var Conversation_EditingMessagePanelTitle: String { return self._s[1347]! }
    public var Watch_Message_Poll: String { return self._s[1348]! }
    public var Privacy_Calls: String { return self._s[1349]! }
    public var Month_ShortAugust: String { return self._s[1350]! }
    public var TwoStepAuth_SetPasswordHelp: String { return self._s[1351]! }
    public var Notifications_Reset: String { return self._s[1352]! }
    public var Conversation_Pin: String { return self._s[1353]! }
    public var Passport_Language_lv: String { return self._s[1354]! }
    public var BlockedUsers_Info: String { return self._s[1355]! }
    public var Watch_Conversation_Unblock: String { return self._s[1358]! }
    public func Time_MonthOfYear_m9(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1359]!, self._r[1359]!, [_0])
    }
    public var CloudStorage_Title: String { return self._s[1360]! }
    public var GroupInfo_DeleteAndExitConfirmation: String { return self._s[1361]! }
    public func NetworkUsageSettings_WifiUsageSince(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1362]!, self._r[1362]!, [_0])
    }
    public var Channel_AdminLogFilter_AdminsTitle: String { return self._s[1363]! }
    public var Watch_Suggestion_OnMyWay: String { return self._s[1364]! }
    public var TwoStepAuth_RecoveryEmailTitle: String { return self._s[1365]! }
    public var Passport_Address_EditBankStatement: String { return self._s[1366]! }
    public var ChatSettings_DownloadInBackgroundInfo: String { return self._s[1367]! }
    public var ShareMenu_Comment: String { return self._s[1368]! }
    public var Permissions_ContactsTitle_v0: String { return self._s[1369]! }
    public var Notifications_PermissionsTitle: String { return self._s[1370]! }
    public var GroupPermission_NoSendLinks: String { return self._s[1371]! }
    public var Settings_Support: String { return self._s[1372]! }
    public var Notifications_ChannelNotificationsSound: String { return self._s[1373]! }
    public var GroupPermission_ApplyAlertAction: String { return self._s[1374]! }
    public var Watch_Stickers_StickerPacks: String { return self._s[1375]! }
    public var Common_Select: String { return self._s[1377]! }
    public var CheckoutInfo_ErrorEmailInvalid: String { return self._s[1378]! }
    public var WallpaperSearch_ColorGray: String { return self._s[1380]! }
    public var ChatAdmins_AllMembersAreAdminsOffHelp: String { return self._s[1381]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5hours: String { return self._s[1382]! }
    public var Appearance_PreviewReplyAuthor: String { return self._s[1383]! }
    public var TwoStepAuth_RecoveryTitle: String { return self._s[1384]! }
    public var Widget_AuthRequired: String { return self._s[1385]! }
    public var Camera_FlashOn: String { return self._s[1386]! }
    public var Channel_Stickers_NotFoundHelp: String { return self._s[1387]! }
    public var Watch_Suggestion_OK: String { return self._s[1388]! }
    public func Username_LinkHint(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1390]!, self._r[1390]!, [_0])
    }
    public func Notification_PinnedLiveLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1392]!, self._r[1392]!, [_0])
    }
    public var DialogList_AdLabel: String { return self._s[1393]! }
    public var WatchRemote_NotificationText: String { return self._s[1394]! }
    public var Conversation_ReportSpam: String { return self._s[1395]! }
    public var Settings_LogoutConfirmationTitle: String { return self._s[1397]! }
    public var PhoneLabel_Title: String { return self._s[1398]! }
    public var Passport_Address_EditRentalAgreement: String { return self._s[1399]! }
    public var Notifications_ExceptionsTitle: String { return self._s[1400]! }
    public var Notifications_AlertTones: String { return self._s[1401]! }
    public var Call_ReportIncludeLogDescription: String { return self._s[1402]! }
    public var AutoDownloadSettings_PrivateChats: String { return self._s[1403]! }
    public var TwoStepAuth_AddHintTitle: String { return self._s[1405]! }
    public var ReportPeer_ReasonOther: String { return self._s[1406]! }
    public var KeyCommand_ScrollDown: String { return self._s[1408]! }
    public func Login_BannedPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1409]!, self._r[1409]!, [_0])
    }
    public var NetworkUsageSettings_MediaVideoDataSection: String { return self._s[1410]! }
    public var ChannelInfo_DeleteGroupConfirmation: String { return self._s[1411]! }
    public var AuthSessions_LogOut: String { return self._s[1412]! }
    public var Passport_Identity_TypeInternalPassport: String { return self._s[1413]! }
    public var ChatSettings_AutoDownloadVoiceMessages: String { return self._s[1414]! }
    public var Passport_Phone_Title: String { return self._s[1415]! }
    public var Settings_PhoneNumber: String { return self._s[1416]! }
    public var NotificationsSound_Alert: String { return self._s[1417]! }
    public var WebSearch_SearchNoResults: String { return self._s[1418]! }
    public var PhotoEditor_CurvesTool: String { return self._s[1420]! }
    public var Checkout_PaymentMethod: String { return self._s[1422]! }
    public func PUSH_CHAT_ADD_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1423]!, self._r[1423]!, [_1, _2])
    }
    public var Contacts_AccessDeniedError: String { return self._s[1424]! }
    public var Camera_PhotoMode: String { return self._s[1427]! }
    public var Passport_Address_AddUtilityBill: String { return self._s[1428]! }
    public var CallSettings_OnMobile: String { return self._s[1429]! }
    public var Tour_Text2: String { return self._s[1430]! }
    public func PUSH_CHAT_MESSAGE_ROUND(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1431]!, self._r[1431]!, [_1, _2])
    }
    public var DialogList_EncryptionProcessing: String { return self._s[1433]! }
    public var Permissions_Skip: String { return self._s[1434]! }
    public var SecretImage_Title: String { return self._s[1435]! }
    public var Watch_MessageView_Title: String { return self._s[1436]! }
    public var AttachmentMenu_Poll: String { return self._s[1437]! }
    public func Notification_GroupInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1438]!, self._r[1438]!, [_0])
    }
    public var Notification_CallCanceled: String { return self._s[1439]! }
    public var WallpaperPreview_Title: String { return self._s[1440]! }
    public var Privacy_PaymentsClear_PaymentInfo: String { return self._s[1441]! }
    public var Settings_ProxyConnecting: String { return self._s[1442]! }
    public var Profile_MessageLifetime5s: String { return self._s[1444]! }
    public var Username_InvalidCharacters: String { return self._s[1445]! }
    public var WallpaperPreview_CropBottomText: String { return self._s[1446]! }
    public var AutoDownloadSettings_LimitBySize: String { return self._s[1447]! }
    public var Settings_AddAccount: String { return self._s[1448]! }
    public var Notification_CreatedChannel: String { return self._s[1451]! }
    public func PUSH_CHAT_DELETE_MEMBER(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1452]!, self._r[1452]!, [_1, _2, _3])
    }
    public var Passcode_AppLockedAlert: String { return self._s[1454]! }
    public var Contacts_TopSection: String { return self._s[1455]! }
    public func Time_MonthOfYear_m6(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1456]!, self._r[1456]!, [_0])
    }
    public var ReportPeer_ReasonSpam: String { return self._s[1457]! }
    public var UserInfo_TapToCall: String { return self._s[1458]! }
    public var Common_Search: String { return self._s[1460]! }
    public var AuthSessions_IncompleteAttemptsInfo: String { return self._s[1461]! }
    public var Message_InvoiceLabel: String { return self._s[1462]! }
    public var Conversation_InputTextPlaceholder: String { return self._s[1463]! }
    public var NetworkUsageSettings_MediaImageDataSection: String { return self._s[1464]! }
    public func Passport_Address_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1465]!, self._r[1465]!, [_0])
    }
    public var Conversation_Info: String { return self._s[1466]! }
    public var Login_InfoDeletePhoto: String { return self._s[1467]! }
    public var Passport_Language_vi: String { return self._s[1469]! }
    public var Conversation_Search: String { return self._s[1470]! }
    public var DialogList_DeleteBotConversationConfirmation: String { return self._s[1471]! }
    public var ReportPeer_ReasonPornography: String { return self._s[1472]! }
    public var AutoDownloadSettings_PhotosTitle: String { return self._s[1473]! }
    public var Conversation_SendMessageErrorGroupRestricted: String { return self._s[1474]! }
    public var Map_LiveLocationGroupDescription: String { return self._s[1475]! }
    public var Channel_Setup_TypeHeader: String { return self._s[1476]! }
    public var AuthSessions_LoggedIn: String { return self._s[1477]! }
    public var Login_SmsRequestState3: String { return self._s[1478]! }
    public var Passport_Address_EditUtilityBill: String { return self._s[1479]! }
    public var Appearance_ReduceMotionInfo: String { return self._s[1480]! }
    public var Channel_Edit_LinkItem: String { return self._s[1481]! }
    public var Privacy_Calls_P2PNever: String { return self._s[1482]! }
    public var Conversation_AddToReadingList: String { return self._s[1484]! }
    public var Message_Animation: String { return self._s[1485]! }
    public var Conversation_DefaultRestrictedMedia: String { return self._s[1486]! }
    public var Map_Unknown: String { return self._s[1487]! }
    public func PUSH_PINNED_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1488]!, self._r[1488]!, [_1, _2])
    }
    public func Passport_FieldOneOf_Or(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1489]!, self._r[1489]!, [_1, _2])
    }
    public var Call_StatusRequesting: String { return self._s[1490]! }
    public var Conversation_SecretChatContextBotAlert: String { return self._s[1491]! }
    public var SocksProxySetup_ProxyStatusChecking: String { return self._s[1492]! }
    public func PUSH_CHAT_MESSAGE_DOC(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1493]!, self._r[1493]!, [_1, _2])
    }
    public var Weekday_Monday: String { return self._s[1494]! }
    public var Update_Skip: String { return self._s[1495]! }
    public var Group_Username_RemoveExistingUsernamesInfo: String { return self._s[1496]! }
    public var Message_PinnedPollMessage: String { return self._s[1497]! }
    public var BlockedUsers_Title: String { return self._s[1498]! }
    public func PUSH_CHANNEL_MESSAGE_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1499]!, self._r[1499]!, [_1])
    }
    public var Username_CheckingUsername: String { return self._s[1500]! }
    public var NotificationsSound_Bell: String { return self._s[1501]! }
    public var Conversation_SendMessageErrorFlood: String { return self._s[1502]! }
    public func Notification_PinnedLocationMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1503]!, self._r[1503]!, [_0])
    }
    public var ChannelMembers_ChannelAdminsTitle: String { return self._s[1504]! }
    public var ChatSettings_Groups: String { return self._s[1505]! }
    public var Your_card_was_declined: String { return self._s[1506]! }
    public var TwoStepAuth_EnterPasswordHelp: String { return self._s[1508]! }
    public var ChatList_Unmute: String { return self._s[1509]! }
    public var PhotoEditor_CurvesAll: String { return self._s[1510]! }
    public var Weekday_ShortTuesday: String { return self._s[1511]! }
    public var DialogList_Read: String { return self._s[1512]! }
    public var ChannelMembers_WhoCanAddMembers_AllMembers: String { return self._s[1513]! }
    public var Passport_Identity_Gender: String { return self._s[1514]! }
    public func Target_ShareGameConfirmationPrivate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1515]!, self._r[1515]!, [_0])
    }
    public var Target_SelectGroup: String { return self._s[1516]! }
    public func DialogList_EncryptedChatStartedIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1518]!, self._r[1518]!, [_0])
    }
    public var Passport_Language_en: String { return self._s[1519]! }
    public var Channel_Username_CreatePublicLinkHelp: String { return self._s[1520]! }
    public var Login_CancelPhoneVerificationContinue: String { return self._s[1521]! }
    public var Checkout_NewCard_PaymentCard: String { return self._s[1523]! }
    public var Login_InfoHelp: String { return self._s[1524]! }
    public var Contacts_PermissionsSuppressWarningTitle: String { return self._s[1525]! }
    public var SocksProxySetup_AddProxy: String { return self._s[1528]! }
    public var CreatePoll_Title: String { return self._s[1529]! }
    public var PasscodeSettings_SimplePasscodeHelp: String { return self._s[1530]! }
    public var UserInfo_GroupsInCommon: String { return self._s[1531]! }
    public var Call_AudioRouteHide: String { return self._s[1532]! }
    public var ContactInfo_PhoneLabelMobile: String { return self._s[1534]! }
    public func ChatList_LeaveGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1535]!, self._r[1535]!, [_0])
    }
    public var TextFormat_Bold: String { return self._s[1536]! }
    public var FastTwoStepSetup_EmailSection: String { return self._s[1537]! }
    public var Notifications_Title: String { return self._s[1538]! }
    public var Group_Username_InvalidTooShort: String { return self._s[1539]! }
    public var Channel_ErrorAddTooMuch: String { return self._s[1540]! }
    public func DialogList_MultipleTypingSuffix(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1541]!, self._r[1541]!, ["\(_0)"])
    }
    public var Stickers_SuggestAdded: String { return self._s[1543]! }
    public var Login_CountryCode: String { return self._s[1544]! }
    public var Map_GetDirections: String { return self._s[1545]! }
    public var Login_PhoneFloodError: String { return self._s[1546]! }
    public func Time_MonthOfYear_m3(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1547]!, self._r[1547]!, [_0])
    }
    public var Settings_SetUsername: String { return self._s[1549]! }
    public var Notification_GroupInviterSelf: String { return self._s[1550]! }
    public var InstantPage_TapToOpenLink: String { return self._s[1551]! }
    public func Notification_ChannelInviter(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1552]!, self._r[1552]!, [_0])
    }
    public var Watch_Suggestion_TalkLater: String { return self._s[1553]! }
    public var SecretChat_Title: String { return self._s[1554]! }
    public var Group_UpgradeNoticeText1: String { return self._s[1555]! }
    public var AuthSessions_Title: String { return self._s[1556]! }
    public var PhotoEditor_CropAuto: String { return self._s[1557]! }
    public var Channel_About_Title: String { return self._s[1558]! }
    public var FastTwoStepSetup_EmailHelp: String { return self._s[1559]! }
    public func Conversation_Bytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1561]!, self._r[1561]!, ["\(_0)"])
    }
    public var Conversation_PinMessageAlert_OnlyPin: String { return self._s[1563]! }
    public var Group_Setup_HistoryVisibleHelp: String { return self._s[1564]! }
    public func PUSH_MESSAGE_GIF(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1565]!, self._r[1565]!, [_1])
    }
    public func SharedMedia_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1567]!, self._r[1567]!, [_0])
    }
    public func TwoStepAuth_RecoveryEmailUnavailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1568]!, self._r[1568]!, [_0])
    }
    public var Privacy_PaymentsClearInfoHelp: String { return self._s[1569]! }
    public var Undo_MessagesDeleted: String { return self._s[1570]! }
    public var Presence_online: String { return self._s[1572]! }
    public var PasscodeSettings_Title: String { return self._s[1573]! }
    public var Passport_Identity_ExpiryDatePlaceholder: String { return self._s[1574]! }
    public var Web_OpenExternal: String { return self._s[1575]! }
    public func AutoNightTheme_AutomaticHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1577]!, self._r[1577]!, [_0])
    }
    public var FastTwoStepSetup_PasswordConfirmationPlaceholder: String { return self._s[1578]! }
    public var Map_YouAreHere: String { return self._s[1579]! }
    public func AuthSessions_Message(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1580]!, self._r[1580]!, [_0])
    }
    public func ChatList_DeleteChatConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1581]!, self._r[1581]!, [_0])
    }
    public var PrivacyLastSeenSettings_AlwaysShareWith: String { return self._s[1582]! }
    public var Target_InviteToGroupErrorAlreadyInvited: String { return self._s[1583]! }
    public func AuthSessions_AppUnofficial(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1584]!, self._r[1584]!, [_0])
    }
    public func DialogList_LiveLocationSharingTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1585]!, self._r[1585]!, [_0])
    }
    public var SocksProxySetup_Username: String { return self._s[1586]! }
    public var Bot_Start: String { return self._s[1587]! }
    public func Channel_AdminLog_EmptyFilterQueryText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1588]!, self._r[1588]!, [_0])
    }
    public func Channel_AdminLog_MessagePinned(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1589]!, self._r[1589]!, [_0])
    }
    public var Contacts_SortByPresence: String { return self._s[1590]! }
    public var Conversation_DiscardVoiceMessageTitle: String { return self._s[1592]! }
    public func PUSH_CHAT_CREATED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1593]!, self._r[1593]!, [_1, _2])
    }
    public func PrivacySettings_LastSeenContactsMinus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1594]!, self._r[1594]!, [_0])
    }
    public var Passport_Email_EnterOtherEmail: String { return self._s[1595]! }
    public var Login_InfoAvatarPhoto: String { return self._s[1596]! }
    public var Privacy_PaymentsClear_ShippingInfo: String { return self._s[1597]! }
    public var Tour_Title4: String { return self._s[1598]! }
    public var Passport_Identity_Translation: String { return self._s[1599]! }
    public var Login_TermsOfServiceLabel: String { return self._s[1601]! }
    public var Passport_Language_it: String { return self._s[1602]! }
    public var KeyCommand_JumpToNextUnreadChat: String { return self._s[1603]! }
    public var Passport_Identity_SelfieHelp: String { return self._s[1604]! }
    public var Conversation_ClearAll: String { return self._s[1606]! }
    public var TwoStepAuth_FloodError: String { return self._s[1608]! }
    public func PUSH_CHANNEL_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1609]!, self._r[1609]!, [_1])
    }
    public var Paint_Delete: String { return self._s[1610]! }
    public func Passport_AcceptHelp(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1611]!, self._r[1611]!, [_1, _2])
    }
    public var Message_PinnedAudioMessage: String { return self._s[1612]! }
    public func Watch_Time_ShortTodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1613]!, self._r[1613]!, [_0])
    }
    public var Notification_Mute1hMin: String { return self._s[1614]! }
    public var Notifications_GroupNotificationsSound: String { return self._s[1615]! }
    public var SocksProxySetup_ShareProxyList: String { return self._s[1616]! }
    public var Conversation_MessageEditedLabel: String { return self._s[1617]! }
    public var Notification_Exceptions_AlwaysOff: String { return self._s[1618]! }
    public func Channel_AdminLog_MessageAdmin(_ _0: String, _ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1619]!, self._r[1619]!, [_0, _1, _2])
    }
    public var NetworkUsageSettings_ResetStats: String { return self._s[1620]! }
    public func PUSH_MESSAGE_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1621]!, self._r[1621]!, [_1])
    }
    public var AccessDenied_LocationTracking: String { return self._s[1622]! }
    public var Month_GenOctober: String { return self._s[1623]! }
    public var GroupInfo_InviteLink_RevokeAlert_Revoke: String { return self._s[1624]! }
    public var EnterPasscode_EnterPasscode: String { return self._s[1625]! }
    public var MediaPicker_TimerTooltip: String { return self._s[1627]! }
    public var SharedMedia_TitleAll: String { return self._s[1628]! }
    public var Conversation_RestrictedMedia: String { return self._s[1631]! }
    public var AccessDenied_PhotosRestricted: String { return self._s[1632]! }
    public var ChangePhoneNumberCode_Called: String { return self._s[1634]! }
    public func Notification_PinnedDocumentMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1635]!, self._r[1635]!, [_0])
    }
    public var Conversation_SavedMessages: String { return self._s[1638]! }
    public var Your_cards_expiration_month_is_invalid: String { return self._s[1640]! }
    public var FastTwoStepSetup_PasswordPlaceholder: String { return self._s[1641]! }
    public func Target_ShareGameConfirmationGroup(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1643]!, self._r[1643]!, [_0])
    }
    public var ReportPeer_AlertSuccess: String { return self._s[1644]! }
    public var PhotoEditor_CropAspectRatioOriginal: String { return self._s[1645]! }
    public func InstantPage_RelatedArticleAuthorAndDateTitle(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1646]!, self._r[1646]!, [_1, _2])
    }
    public var Checkout_PasswordEntry_Title: String { return self._s[1647]! }
    public var PhotoEditor_FadeTool: String { return self._s[1648]! }
    public var Privacy_ContactsReset: String { return self._s[1649]! }
    public func Channel_AdminLog_MessageRestrictedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1651]!, self._r[1651]!, [_0])
    }
    public var Message_PinnedVideoMessage: String { return self._s[1652]! }
    public var ChatList_Mute: String { return self._s[1653]! }
    public var Permissions_CellularDataText_v0: String { return self._s[1654]! }
    public var ShareMenu_SelectChats: String { return self._s[1656]! }
    public var MusicPlayer_VoiceNote: String { return self._s[1657]! }
    public var Conversation_RestrictedText: String { return self._s[1658]! }
    public var TwoStepAuth_DisableSuccess: String { return self._s[1659]! }
    public var Cache_Videos: String { return self._s[1660]! }
    public var FeatureDisabled_Oops: String { return self._s[1662]! }
    public var Passport_Address_PostcodePlaceholder: String { return self._s[1663]! }
    public var Stickers_GroupStickersHelp: String { return self._s[1664]! }
    public var GroupPermission_NoSendPolls: String { return self._s[1665]! }
    public var Message_VideoExpired: String { return self._s[1667]! }
    public var Notifications_Badge: String { return self._s[1668]! }
    public var GroupInfo_GroupHistoryVisible: String { return self._s[1669]! }
    public var CreatePoll_OptionPlaceholder: String { return self._s[1670]! }
    public var Username_InvalidTooShort: String { return self._s[1671]! }
    public var EnterPasscode_EnterNewPasscodeChange: String { return self._s[1672]! }
    public var Channel_AdminLog_PinMessages: String { return self._s[1673]! }
    public func Notification_MessageLifetimeRemoved(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1674]!, self._r[1674]!, [_1])
    }
    public var Permissions_SiriAllowInSettings_v0: String { return self._s[1675]! }
    public var Conversation_DefaultRestrictedText: String { return self._s[1676]! }
    public var SharedMedia_CategoryDocs: String { return self._s[1679]! }
    public func PUSH_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1680]!, self._r[1680]!, [_1])
    }
    public func Notification_MessageLifetimeChangedOutgoing(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1682]!, self._r[1682]!, [_1])
    }
    public var CheckoutInfo_ErrorShippingNotAvailable: String { return self._s[1683]! }
    public func Time_MonthOfYear_m12(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1684]!, self._r[1684]!, [_0])
    }
    public var ChatSettings_PrivateChats: String { return self._s[1685]! }
    public var Channel_UpdatePhotoItem: String { return self._s[1686]! }
    public var GroupInfo_LeftStatus: String { return self._s[1687]! }
    public var Watch_MessageView_Forward: String { return self._s[1689]! }
    public var ReportPeer_ReasonChildAbuse: String { return self._s[1690]! }
    public var Cache_ClearEmpty: String { return self._s[1692]! }
    public var Localization_LanguageName: String { return self._s[1693]! }
    public var WebSearch_GIFs: String { return self._s[1694]! }
    public var Notifications_DisplayNamesOnLockScreenInfoWithLink: String { return self._s[1695]! }
    public var Username_InvalidStartsWithNumber: String { return self._s[1696]! }
    public var Common_Back: String { return self._s[1697]! }
    public var Passport_Identity_DateOfBirthPlaceholder: String { return self._s[1698]! }
    public func PUSH_CHANNEL_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1699]!, self._r[1699]!, [_1, _2])
    }
    public var Passport_Email_Help: String { return self._s[1700]! }
    public var Watch_Conversation_Reply: String { return self._s[1702]! }
    public var Conversation_EditingMessageMediaChange: String { return self._s[1704]! }
    public var Passport_Identity_IssueDatePlaceholder: String { return self._s[1705]! }
    public var Channel_BanUser_Unban: String { return self._s[1707]! }
    public var Channel_EditAdmin_PermissionPostMessages: String { return self._s[1708]! }
    public var Group_Username_CreatePublicLinkHelp: String { return self._s[1709]! }
    public var TwoStepAuth_ConfirmEmailCodePlaceholder: String { return self._s[1711]! }
    public var Passport_Identity_Name: String { return self._s[1712]! }
    public var GroupRemoved_ViewUserInfo: String { return self._s[1713]! }
    public var Conversation_BlockUser: String { return self._s[1714]! }
    public var Month_GenJanuary: String { return self._s[1715]! }
    public var ChatSettings_TextSize: String { return self._s[1716]! }
    public var Notification_PassportValuePhone: String { return self._s[1717]! }
    public var Passport_Language_ne: String { return self._s[1718]! }
    public var Notification_CallBack: String { return self._s[1719]! }
    public var TwoStepAuth_EmailHelp: String { return self._s[1720]! }
    public func Time_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1721]!, self._r[1721]!, [_0])
    }
    public var Channel_Info_Management: String { return self._s[1722]! }
    public var Passport_FieldIdentityUploadHelp: String { return self._s[1723]! }
    public var Stickers_FrequentlyUsed: String { return self._s[1724]! }
    public var Channel_BanUser_PermissionSendMessages: String { return self._s[1725]! }
    public var Passport_Address_OneOfTypeUtilityBill: String { return self._s[1727]! }
    public func LOCAL_CHANNEL_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1728]!, self._r[1728]!, [_1, "\(_2)"])
    }
    public var Passport_Address_EditResidentialAddress: String { return self._s[1729]! }
    public var PrivacyPolicy_DeclineTitle: String { return self._s[1730]! }
    public var CreatePoll_TextHeader: String { return self._s[1731]! }
    public func Checkout_SavePasswordTimeoutAndTouchId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1732]!, self._r[1732]!, [_0])
    }
    public var PhotoEditor_QualityMedium: String { return self._s[1733]! }
    public var InfoPlist_NSMicrophoneUsageDescription: String { return self._s[1734]! }
    public var Conversation_StatusKickedFromChannel: String { return self._s[1736]! }
    public var CheckoutInfo_ReceiverInfoName: String { return self._s[1737]! }
    public var Group_ErrorSendRestrictedStickers: String { return self._s[1738]! }
    public func Conversation_RestrictedInlineTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1739]!, self._r[1739]!, [_0])
    }
    public var Conversation_LinkDialogOpen: String { return self._s[1741]! }
    public func PUSH_CHAT_MESSAGES(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1742]!, self._r[1742]!, [_1, _2, _3])
    }
    public var Settings_Username: String { return self._s[1743]! }
    public var Wallpaper_Wallpaper: String { return self._s[1745]! }
    public var SocksProxySetup_UseProxy: String { return self._s[1747]! }
    public var UserInfo_ShareMyContactInfo: String { return self._s[1748]! }
    public var MessageTimer_Forever: String { return self._s[1749]! }
    public var Privacy_Calls_WhoCanCallMe: String { return self._s[1750]! }
    public var PhotoEditor_DiscardChanges: String { return self._s[1751]! }
    public var AuthSessions_TerminateOtherSessionsHelp: String { return self._s[1752]! }
    public var Passport_Language_da: String { return self._s[1753]! }
    public var SocksProxySetup_PortPlaceholder: String { return self._s[1754]! }
    public func SecretGIF_NotViewedYet(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1755]!, self._r[1755]!, [_0])
    }
    public var Passport_Address_EditPassportRegistration: String { return self._s[1756]! }
    public func Channel_AdminLog_MessageChangedGroupAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1758]!, self._r[1758]!, [_0])
    }
    public var Passport_Identity_ResidenceCountryPlaceholder: String { return self._s[1760]! }
    public var Conversation_SearchByName_Prefix: String { return self._s[1761]! }
    public var Conversation_PinnedPoll: String { return self._s[1762]! }
    public var Conversation_EmptyGifPanelPlaceholder: String { return self._s[1763]! }
    public func PUSH_ENCRYPTION_ACCEPT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1764]!, self._r[1764]!, [_1])
    }
    public var WallpaperSearch_ColorPurple: String { return self._s[1765]! }
    public var Cache_ByPeerHeader: String { return self._s[1766]! }
    public func Conversation_EncryptedPlaceholderTitleIncoming(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1767]!, self._r[1767]!, [_0])
    }
    public var ChatSettings_AutoDownloadDocuments: String { return self._s[1768]! }
    public var Notification_PinnedMessage: String { return self._s[1771]! }
    public var Contacts_SortBy: String { return self._s[1773]! }
    public func PUSH_CHANNEL_MESSAGE_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1774]!, self._r[1774]!, [_1])
    }
    public func PUSH_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1776]!, self._r[1776]!, [_1, _2])
    }
    public var Call_EncryptionKey_Title: String { return self._s[1777]! }
    public var Watch_UserInfo_Service: String { return self._s[1778]! }
    public var Conversation_Unpin: String { return self._s[1781]! }
    public var CancelResetAccount_Title: String { return self._s[1782]! }
    public var Map_LiveLocationFor15Minutes: String { return self._s[1783]! }
    public func Time_PreciseDate_m8(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1785]!, self._r[1785]!, [_1, _2, _3])
    }
    public var Group_Members_AddMemberBotErrorNotAllowed: String { return self._s[1786]! }
    public var CallSettings_Title: String { return self._s[1787]! }
    public var PasscodeSettings_EncryptDataHelp: String { return self._s[1789]! }
    public var AutoDownloadSettings_Contacts: String { return self._s[1790]! }
    public var Passport_Identity_DocumentDetails: String { return self._s[1791]! }
    public var LoginPassword_PasswordHelp: String { return self._s[1792]! }
    public var PrivacyLastSeenSettings_CustomShareSettings_Delete: String { return self._s[1793]! }
    public var Checkout_TotalPaidAmount: String { return self._s[1794]! }
    public func FileSize_KB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1795]!, self._r[1795]!, [_0])
    }
    public var PasscodeSettings_ChangePasscode: String { return self._s[1796]! }
    public var Conversation_SecretLinkPreviewAlert: String { return self._s[1798]! }
    public var Privacy_SecretChatsLinkPreviews: String { return self._s[1799]! }
    public func PUSH_CHANNEL_MESSAGE_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1800]!, self._r[1800]!, [_1])
    }
    public var Contacts_InviteFriends: String { return self._s[1802]! }
    public var Map_ChooseLocationTitle: String { return self._s[1803]! }
    public var Conversation_StopPoll: String { return self._s[1805]! }
    public func WebSearch_SearchNoResultsDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1806]!, self._r[1806]!, [_0])
    }
    public var Calls_RatingFeedback: String { return self._s[1807]! }
    public var GroupInfo_BroadcastListNamePlaceholder: String { return self._s[1808]! }
    public var NotificationsSound_Pulse: String { return self._s[1809]! }
    public var Watch_LastSeen_Lately: String { return self._s[1810]! }
    public var Widget_NoUsers: String { return self._s[1813]! }
    public var Conversation_UnvotePoll: String { return self._s[1814]! }
    public var NotificationsSound_Circles: String { return self._s[1816]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Title: String { return self._s[1818]! }
    public var TwoStepAuth_RecoveryCodeExpired: String { return self._s[1819]! }
    public var Proxy_TooltipUnavailable: String { return self._s[1820]! }
    public var Passport_Identity_CountryPlaceholder: String { return self._s[1822]! }
    public var Conversation_FileDropbox: String { return self._s[1824]! }
    public var Notifications_ExceptionsUnmuted: String { return self._s[1825]! }
    public var Tour_Text3: String { return self._s[1827]! }
    public var Login_ResetAccountProtected_Title: String { return self._s[1829]! }
    public var GroupPermission_NoSendMessages: String { return self._s[1830]! }
    public var WallpaperSearch_ColorTitle: String { return self._s[1831]! }
    public var ChatAdmins_AllMembersAreAdminsOnHelp: String { return self._s[1832]! }
    public func Conversation_LiveLocationYouAnd(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1834]!, self._r[1834]!, [_0])
    }
    public var GroupInfo_AddParticipantTitle: String { return self._s[1835]! }
    public var Checkout_ShippingOption_Title: String { return self._s[1836]! }
    public var ChatSettings_AutoDownloadTitle: String { return self._s[1837]! }
    public func DialogList_SingleTypingSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1838]!, self._r[1838]!, [_0])
    }
    public var PrivacyLastSeenSettings_NeverShareWith_Placeholder: String { return self._s[1839]! }
    public var Appearance_PreviewIncomingText: String { return self._s[1841]! }
    public var ChannelInfo_ConfirmLeave: String { return self._s[1842]! }
    public var MediaPicker_MomentsDateRangeSameMonthYearFormat: String { return self._s[1843]! }
    public var Passport_Identity_DocumentNumberPlaceholder: String { return self._s[1844]! }
    public var Channel_AdminLogFilter_EventsNewMembers: String { return self._s[1845]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_5minutes: String { return self._s[1846]! }
    public var GroupInfo_SetGroupPhotoStop: String { return self._s[1847]! }
    public var Notification_SecretChatScreenshot: String { return self._s[1848]! }
    public var AccessDenied_Wallpapers: String { return self._s[1849]! }
    public var Passport_Address_City: String { return self._s[1851]! }
    public var InfoPlist_NSPhotoLibraryAddUsageDescription: String { return self._s[1852]! }
    public var SocksProxySetup_SecretPlaceholder: String { return self._s[1853]! }
    public var AccessDenied_LocationDisabled: String { return self._s[1854]! }
    public var SocksProxySetup_HostnamePlaceholder: String { return self._s[1856]! }
    public var GroupInfo_Sound: String { return self._s[1857]! }
    public var Stickers_RemoveFromFavorites: String { return self._s[1858]! }
    public var Contacts_Title: String { return self._s[1859]! }
    public var Passport_Language_fr: String { return self._s[1860]! }
    public var Notifications_ResetAllNotifications: String { return self._s[1861]! }
    public var PrivacySettings_SecurityTitle: String { return self._s[1864]! }
    public var Checkout_NewCard_Title: String { return self._s[1865]! }
    public var Login_HaveNotReceivedCodeInternal: String { return self._s[1866]! }
    public var Conversation_ForwardChats: String { return self._s[1867]! }
    public var Settings_FAQ: String { return self._s[1870]! }
    public var AutoDownloadSettings_DocumentsTitle: String { return self._s[1871]! }
    public var Conversation_ContextMenuForward: String { return self._s[1872]! }
    public var PrivacyPolicy_Title: String { return self._s[1877]! }
    public var Notifications_TextTone: String { return self._s[1878]! }
    public var Profile_CreateNewContact: String { return self._s[1879]! }
    public var AutoNightTheme_AutomaticSection: String { return self._s[1881]! }
    public var Channel_Username_InvalidCharacters: String { return self._s[1883]! }
    public func Channel_AdminLog_MessageChangedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1884]!, self._r[1884]!, [_0])
    }
    public var PrivacySettings_LastSeenTitle: String { return self._s[1885]! }
    public var Channel_AdminLog_CanInviteUsers: String { return self._s[1886]! }
    public var Conversation_MessageDeliveryFailed: String { return self._s[1887]! }
    public var Watch_ChatList_NoConversationsText: String { return self._s[1888]! }
    public var Bot_Unblock: String { return self._s[1889]! }
    public var TextFormat_Italic: String { return self._s[1890]! }
    public var WallpaperSearch_ColorPink: String { return self._s[1891]! }
    public var Weekday_Wednesday: String { return self._s[1892]! }
    public var Settings_About_Help: String { return self._s[1893]! }
    public var SearchImages_Title: String { return self._s[1894]! }
    public var Conversation_ClousStorageInfo_Description1: String { return self._s[1895]! }
    public var ExplicitContent_AlertTitle: String { return self._s[1896]! }
    public func Time_PreciseDate_m5(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1897]!, self._r[1897]!, [_1, _2, _3])
    }
    public var Weekday_Thursday: String { return self._s[1898]! }
    public var Channel_BanUser_PermissionChangeGroupInfo: String { return self._s[1899]! }
    public var Channel_Members_AddMembersHelp: String { return self._s[1900]! }
    public func Checkout_SavePasswordTimeout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1901]!, self._r[1901]!, [_0])
    }
    public var Passport_RequestedInformation: String { return self._s[1902]! }
    public var Login_PhoneAndCountryHelp: String { return self._s[1903]! }
    public var Conversation_EncryptionProcessing: String { return self._s[1905]! }
    public var Notifications_PermissionsSuppressWarningTitle: String { return self._s[1906]! }
    public var PhotoEditor_EnhanceTool: String { return self._s[1908]! }
    public var Channel_Setup_Title: String { return self._s[1909]! }
    public var Conversation_SearchPlaceholder: String { return self._s[1910]! }
    public var AccessDenied_LocationAlwaysDenied: String { return self._s[1911]! }
    public var Checkout_ErrorGeneric: String { return self._s[1912]! }
    public var Passport_Language_hu: String { return self._s[1913]! }
    public func Passport_Identity_UploadOneOfScan(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1915]!, self._r[1915]!, [_0])
    }
    public func PUSH_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1918]!, self._r[1918]!, [_1])
    }
    public var Conversation_CloudStorageInfo_Title: String { return self._s[1919]! }
    public var PhotoEditor_CropAspectRatioSquare: String { return self._s[1920]! }
    public func Notification_Exceptions_MutedUntil(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1921]!, self._r[1921]!, [_0])
    }
    public var Conversation_ClearPrivateHistory: String { return self._s[1922]! }
    public var ContactInfo_PhoneLabelHome: String { return self._s[1923]! }
    public var PrivacySettings_LastSeenContacts: String { return self._s[1924]! }
    public func ChangePhone_ErrorOccupied(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1925]!, self._r[1925]!, [_0])
    }
    public var Passport_Language_cs: String { return self._s[1926]! }
    public var Message_PinnedAnimationMessage: String { return self._s[1928]! }
    public var Passport_Identity_ReverseSideHelp: String { return self._s[1930]! }
    public var Embed_PlayingInPIP: String { return self._s[1932]! }
    public var AutoNightTheme_ScheduleSection: String { return self._s[1933]! }
    public func Call_EmojiDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1934]!, self._r[1934]!, [_0])
    }
    public var MediaPicker_LivePhotoDescription: String { return self._s[1935]! }
    public func Channel_AdminLog_MessageRestrictedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1936]!, self._r[1936]!, [_1])
    }
    public var Notification_PaymentSent: String { return self._s[1937]! }
    public var PhotoEditor_CurvesGreen: String { return self._s[1938]! }
    public var SaveIncomingPhotosSettings_Title: String { return self._s[1939]! }
    public func PUSH_MESSAGE_SCREENSHOT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1942]!, self._r[1942]!, [_1])
    }
    public func PUSH_MESSAGE_PHOTO_SECRET(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1943]!, self._r[1943]!, [_1])
    }
    public func ApplyLanguage_UnsufficientDataText(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1944]!, self._r[1944]!, [_1])
    }
    public var NetworkUsageSettings_CallDataSection: String { return self._s[1946]! }
    public var PasscodeSettings_HelpTop: String { return self._s[1947]! }
    public var Passport_Address_TypeRentalAgreement: String { return self._s[1948]! }
    public var ReportPeer_ReasonOther_Placeholder: String { return self._s[1949]! }
    public var CheckoutInfo_ErrorPhoneInvalid: String { return self._s[1950]! }
    public var Call_Accept: String { return self._s[1952]! }
    public var GroupRemoved_RemoveInfo: String { return self._s[1953]! }
    public var Month_GenMarch: String { return self._s[1954]! }
    public var PhotoEditor_ShadowsTool: String { return self._s[1955]! }
    public var LoginPassword_Title: String { return self._s[1956]! }
    public var Watch_Conversation_GroupInfo: String { return self._s[1957]! }
    public var CallSettings_Always: String { return self._s[1958]! }
    public var CallFeedback_Success: String { return self._s[1959]! }
    public var TwoStepAuth_SetupHint: String { return self._s[1960]! }
    public var ConversationProfile_UsersTooMuchError: String { return self._s[1961]! }
    public var Login_PhoneTitle: String { return self._s[1962]! }
    public var Passport_FieldPhoneHelp: String { return self._s[1963]! }
    public var Weekday_ShortSunday: String { return self._s[1964]! }
    public var Passport_InfoFAQ_URL: String { return self._s[1965]! }
    public var ContactInfo_Job: String { return self._s[1967]! }
    public var UserInfo_InviteBotToGroup: String { return self._s[1968]! }
    public var TwoStepAuth_PasswordRemovePassportConfirmation: String { return self._s[1969]! }
    public var Passport_DeletePersonalDetailsConfirmation: String { return self._s[1970]! }
    public var CallFeedback_ReasonNoise: String { return self._s[1971]! }
    public var Passport_Identity_AddInternalPassport: String { return self._s[1973]! }
    public var MediaPicker_AddCaption: String { return self._s[1974]! }
    public var CallSettings_TabIconDescription: String { return self._s[1975]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow: String { return self._s[1976]! }
    public var Passport_Identity_TypePersonalDetails: String { return self._s[1977]! }
    public var DialogList_SearchSectionRecent: String { return self._s[1978]! }
    public var PrivacyPolicy_DeclineMessage: String { return self._s[1979]! }
    public var LastSeen_WithinAWeek: String { return self._s[1982]! }
    public var ChannelMembers_GroupAdminsTitle: String { return self._s[1983]! }
    public var Conversation_CloudStorage_ChatStatus: String { return self._s[1985]! }
    public var Passport_Address_TypeResidentialAddress: String { return self._s[1986]! }
    public var Conversation_StatusLeftGroup: String { return self._s[1987]! }
    public var SocksProxySetup_ProxyDetailsTitle: String { return self._s[1988]! }
    public var GroupPermission_AddSuccess: String { return self._s[1990]! }
    public var PhotoEditor_BlurToolRadial: String { return self._s[1992]! }
    public var Conversation_ContextMenuCopy: String { return self._s[1993]! }
    public var AccessDenied_CallMicrophone: String { return self._s[1994]! }
    public func Time_PreciseDate_m2(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[1995]!, self._r[1995]!, [_1, _2, _3])
    }
    public var Login_InvalidFirstNameError: String { return self._s[1996]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOn: String { return self._s[1997]! }
    public var Checkout_PaymentMethod_New: String { return self._s[1998]! }
    public var ShareMenu_CopyShareLinkGame: String { return self._s[1999]! }
    public var PhotoEditor_QualityTool: String { return self._s[2000]! }
    public var Login_SendCodeViaSms: String { return self._s[2001]! }
    public var Login_EmailNotConfiguredError: String { return self._s[2002]! }
    public var PrivacyPolicy_Accept: String { return self._s[2003]! }
    public var Notifications_ExceptionsMessagePlaceholder: String { return self._s[2004]! }
    public func PUSH_CHAT_MESSAGE_TEXT(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2005]!, self._r[2005]!, [_1, _2, _3])
    }
    public var InfoPlist_NSLocationAlwaysUsageDescription: String { return self._s[2006]! }
    public var AutoNightTheme_Automatic: String { return self._s[2007]! }
    public var Channel_Username_InvalidStartsWithNumber: String { return self._s[2008]! }
    public var Privacy_ContactsSyncHelp: String { return self._s[2009]! }
    public var Cache_Help: String { return self._s[2010]! }
    public var Passport_Language_fa: String { return self._s[2011]! }
    public var Login_ResetAccountProtected_TimerTitle: String { return self._s[2012]! }
    public var PrivacySettings_LastSeen: String { return self._s[2013]! }
    public func DialogList_MultipleTyping(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2014]!, self._r[2014]!, [_0, _1])
    }
    public var Preview_SaveGif: String { return self._s[2018]! }
    public var Profile_About: String { return self._s[2019]! }
    public var Channel_About_Placeholder: String { return self._s[2020]! }
    public var Login_InfoTitle: String { return self._s[2021]! }
    public func TwoStepAuth_SetupPendingEmail(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2022]!, self._r[2022]!, [_0])
    }
    public var Watch_Suggestion_CantTalk: String { return self._s[2024]! }
    public var ContactInfo_Title: String { return self._s[2025]! }
    public var Media_ShareThisVideo: String { return self._s[2026]! }
    public var Weekday_ShortFriday: String { return self._s[2027]! }
    public var AccessDenied_Contacts: String { return self._s[2028]! }
    public var Notification_CallIncomingShort: String { return self._s[2029]! }
    public var Group_Setup_TypePublic: String { return self._s[2030]! }
    public var Notifications_MessageNotificationsExceptions: String { return self._s[2031]! }
    public var Notifications_Badge_IncludeChannels: String { return self._s[2032]! }
    public var Notifications_MessageNotificationsPreview: String { return self._s[2035]! }
    public var ConversationProfile_ErrorCreatingConversation: String { return self._s[2036]! }
    public var Group_ErrorAddTooMuchBots: String { return self._s[2037]! }
    public var Privacy_GroupsAndChannels_CustomShareHelp: String { return self._s[2038]! }
    public var Permissions_CellularDataAllowInSettings_v0: String { return self._s[2039]! }
    public var DialogList_Typing: String { return self._s[2040]! }
    public var CallFeedback_IncludeLogs: String { return self._s[2042]! }
    public var Checkout_Phone: String { return self._s[2044]! }
    public var Login_InfoFirstNamePlaceholder: String { return self._s[2047]! }
    public var Privacy_Calls_Integration: String { return self._s[2048]! }
    public var Notifications_PermissionsAllow: String { return self._s[2049]! }
    public var TwoStepAuth_AddHintDescription: String { return self._s[2053]! }
    public var Settings_ChatSettings: String { return self._s[2054]! }
    public func Channel_AdminLog_MessageInvitedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2055]!, self._r[2055]!, [_1, _2])
    }
    public var GroupRemoved_DeleteUser: String { return self._s[2057]! }
    public func Channel_AdminLog_PollStopped(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2058]!, self._r[2058]!, [_0])
    }
    public func PUSH_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2059]!, self._r[2059]!, [_1])
    }
    public var Login_ContinueWithLocalization: String { return self._s[2060]! }
    public var Watch_Message_ForwardedFrom: String { return self._s[2061]! }
    public var TwoStepAuth_EnterEmailCode: String { return self._s[2063]! }
    public var Conversation_Unblock: String { return self._s[2064]! }
    public var PrivacySettings_DataSettings: String { return self._s[2065]! }
    public var Notifications_InAppNotificationsVibrate: String { return self._s[2066]! }
    public func Privacy_GroupsAndChannels_InviteToChannelError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2067]!, self._r[2067]!, [_0, _1])
    }
    public var PrivacySettings_Passcode: String { return self._s[2070]! }
    public var Passport_Language_dz: String { return self._s[2071]! }
    public var Passport_Language_tk: String { return self._s[2072]! }
    public func Login_EmailCodeSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2073]!, self._r[2073]!, [_0])
    }
    public var InfoPlist_NSPhotoLibraryUsageDescription: String { return self._s[2074]! }
    public var Conversation_ContextMenuReply: String { return self._s[2075]! }
    public var WallpaperSearch_ColorBrown: String { return self._s[2076]! }
    public var Tour_Title1: String { return self._s[2077]! }
    public var Conversation_ClearGroupHistory: String { return self._s[2079]! }
    public var WallpaperPreview_Motion: String { return self._s[2080]! }
    public func Checkout_PasswordEntry_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2081]!, self._r[2081]!, [_0])
    }
    public var Call_RateCall: String { return self._s[2082]! }
    public var Channel_AdminLog_BanSendStickersAndGifs: String { return self._s[2083]! }
    public var Passport_PasswordCompleteSetup: String { return self._s[2084]! }
    public var Conversation_InputTextSilentBroadcastPlaceholder: String { return self._s[2085]! }
    public var UserInfo_LastNamePlaceholder: String { return self._s[2087]! }
    public func Login_WillCallYou(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2089]!, self._r[2089]!, [_0])
    }
    public var Compose_Create: String { return self._s[2090]! }
    public var Contacts_InviteToTelegram: String { return self._s[2091]! }
    public var GroupInfo_Notifications: String { return self._s[2092]! }
    public var Message_PinnedLiveLocationMessage: String { return self._s[2094]! }
    public var Month_GenApril: String { return self._s[2095]! }
    public var Appearance_AutoNightTheme: String { return self._s[2096]! }
    public var ChatSettings_AutomaticAudioDownload: String { return self._s[2098]! }
    public var Login_CodeSentSms: String { return self._s[2100]! }
    public func UserInfo_UnblockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2101]!, self._r[2101]!, [_0])
    }
    public var EmptyGroupInfo_Line3: String { return self._s[2102]! }
    public var Passport_Language_hr: String { return self._s[2103]! }
    public func Channel_AdminLog_MessageRestrictedNewSetting(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2104]!, self._r[2104]!, [_0])
    }
    public var GroupInfo_InviteLink_CopyLink: String { return self._s[2105]! }
    public var Conversation_InputTextBroadcastPlaceholder: String { return self._s[2106]! }
    public var Privacy_SecretChatsTitle: String { return self._s[2107]! }
    public var Notification_SecretChatMessageScreenshotSelf: String { return self._s[2109]! }
    public var GroupInfo_AddUserLeftError: String { return self._s[2110]! }
    public var Preview_DeleteGif: String { return self._s[2111]! }
    public var GroupInfo_Permissions_Exceptions: String { return self._s[2112]! }
    public var Group_ErrorNotMutualContact: String { return self._s[2113]! }
    public var Notification_MessageLifetime5s: String { return self._s[2114]! }
    public func Watch_LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2115]!, self._r[2115]!, [_0])
    }
    public var Passport_Address_AddBankStatement: String { return self._s[2117]! }
    public var Notification_CallIncoming: String { return self._s[2118]! }
    public var Compose_NewGroupTitle: String { return self._s[2119]! }
    public var TwoStepAuth_RecoveryCodeHelp: String { return self._s[2121]! }
    public var Passport_Address_Postcode: String { return self._s[2123]! }
    public func LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2124]!, self._r[2124]!, [_0])
    }
    public var Checkout_NewCard_SaveInfoHelp: String { return self._s[2125]! }
    public var WallpaperColors_Title: String { return self._s[2126]! }
    public var SocksProxySetup_ShareQRCodeInfo: String { return self._s[2127]! }
    public var GroupPermission_Duration: String { return self._s[2128]! }
    public func Cache_Clear(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2129]!, self._r[2129]!, [_0])
    }
    public var Bot_GroupStatusDoesNotReadHistory: String { return self._s[2130]! }
    public var Username_Placeholder: String { return self._s[2131]! }
    public var CallFeedback_WhatWentWrong: String { return self._s[2132]! }
    public var Passport_FieldAddressUploadHelp: String { return self._s[2133]! }
    public var Permissions_NotificationsAllowInSettings_v0: String { return self._s[2134]! }
    public var Passport_PasswordDescription: String { return self._s[2136]! }
    public var Channel_MessagePhotoUpdated: String { return self._s[2137]! }
    public var MediaPicker_TapToUngroupDescription: String { return self._s[2138]! }
    public var AttachmentMenu_PhotoOrVideo: String { return self._s[2139]! }
    public var Conversation_ContextMenuMore: String { return self._s[2140]! }
    public var Privacy_PaymentsClearInfo: String { return self._s[2141]! }
    public var CallSettings_TabIcon: String { return self._s[2142]! }
    public var KeyCommand_Find: String { return self._s[2143]! }
    public var Message_PinnedGame: String { return self._s[2144]! }
    public var Notifications_Badge_CountUnreadMessages_InfoOff: String { return self._s[2145]! }
    public var Login_CallRequestState2: String { return self._s[2147]! }
    public var CheckoutInfo_ReceiverInfoNamePlaceholder: String { return self._s[2149]! }
    public func Checkout_PayPrice(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2151]!, self._r[2151]!, [_0])
    }
    public var WallpaperPreview_Blurred: String { return self._s[2152]! }
    public var Conversation_InstantPagePreview: String { return self._s[2153]! }
    public func DialogList_SingleUploadingVideoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2154]!, self._r[2154]!, [_0])
    }
    public var SecretTimer_VideoDescription: String { return self._s[2157]! }
    public var WallpaperSearch_ColorRed: String { return self._s[2158]! }
    public var GroupPermission_NoPinMessages: String { return self._s[2159]! }
    public var Passport_Language_es: String { return self._s[2160]! }
    public var Permissions_ContactsAllow_v0: String { return self._s[2162]! }
    public var Conversation_EditingMessageMediaEditCurrentVideo: String { return self._s[2163]! }
    public func PUSH_CHAT_MESSAGE_CONTACT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2164]!, self._r[2164]!, [_1, _2])
    }
    public var WebPreview_GettingLinkInfo: String { return self._s[2165]! }
    public var Watch_UserInfo_Unmute: String { return self._s[2166]! }
    public var GroupInfo_ChannelListNamePlaceholder: String { return self._s[2167]! }
    public var AccessDenied_CameraRestricted: String { return self._s[2169]! }
    public func Conversation_Kilobytes(_ _0: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2170]!, self._r[2170]!, ["\(_0)"])
    }
    public var ChatList_ReadAll: String { return self._s[2172]! }
    public var Settings_CopyUsername: String { return self._s[2173]! }
    public var Contacts_SearchLabel: String { return self._s[2174]! }
    public var Map_OpenInYandexNavigator: String { return self._s[2176]! }
    public var PasscodeSettings_EncryptData: String { return self._s[2177]! }
    public var WallpaperSearch_ColorPrefix: String { return self._s[2178]! }
    public var Notifications_GroupNotificationsPreview: String { return self._s[2179]! }
    public var DialogList_AdNoticeAlert: String { return self._s[2180]! }
    public var CheckoutInfo_ShippingInfoAddress1: String { return self._s[2182]! }
    public var CheckoutInfo_ShippingInfoAddress2: String { return self._s[2183]! }
    public var Localization_LanguageCustom: String { return self._s[2184]! }
    public var Passport_Identity_TypeDriversLicenseUploadScan: String { return self._s[2185]! }
    public var CallFeedback_Title: String { return self._s[2186]! }
    public var Passport_Address_OneOfTypePassportRegistration: String { return self._s[2189]! }
    public var Conversation_InfoGroup: String { return self._s[2190]! }
    public var Compose_NewMessage: String { return self._s[2191]! }
    public var FastTwoStepSetup_HintPlaceholder: String { return self._s[2192]! }
    public var ChatSettings_AutoDownloadVideoMessages: String { return self._s[2193]! }
    public func Passport_Scans_ScanIndex(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2194]!, self._r[2194]!, [_0])
    }
    public var Channel_AdminLog_CanDeleteMessages: String { return self._s[2195]! }
    public var Login_CancelSignUpConfirmation: String { return self._s[2196]! }
    public var ChangePhoneNumberCode_Help: String { return self._s[2197]! }
    public var PrivacySettings_DeleteAccountHelp: String { return self._s[2198]! }
    public var Channel_BlackList_Title: String { return self._s[2199]! }
    public var UserInfo_PhoneCall: String { return self._s[2200]! }
    public var Passport_Address_OneOfTypeBankStatement: String { return self._s[2202]! }
    public var State_connecting: String { return self._s[2203]! }
    public var WallpaperPreview_Color: String { return self._s[2204]! }
    public func DialogList_SingleRecordingAudioSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2205]!, self._r[2205]!, [_0])
    }
    public var Notifications_GroupNotifications: String { return self._s[2206]! }
    public var Passport_Identity_EditPassport: String { return self._s[2207]! }
    public var EnterPasscode_RepeatNewPasscode: String { return self._s[2209]! }
    public var Localization_EnglishLanguageName: String { return self._s[2210]! }
    public var Share_AuthDescription: String { return self._s[2211]! }
    public var Passport_Identity_Surname: String { return self._s[2212]! }
    public var Compose_TokenListPlaceholder: String { return self._s[2213]! }
    public var Passport_Identity_OneOfTypePassport: String { return self._s[2214]! }
    public var Settings_AboutEmpty: String { return self._s[2215]! }
    public var Conversation_Unmute: String { return self._s[2216]! }
    public func PUSH_CONTACT_JOINED(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2218]!, self._r[2218]!, [_1])
    }
    public var Login_CodeSentCall: String { return self._s[2219]! }
    public var ContactInfo_PhoneLabelHomeFax: String { return self._s[2221]! }
    public var ChatSettings_Appearance: String { return self._s[2222]! }
    public var Appearance_PickAccentColor: String { return self._s[2223]! }
    public func PUSH_CHAT_MESSAGE_NOTEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2224]!, self._r[2224]!, [_1, _2])
    }
    public func PUSH_MESSAGE_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2225]!, self._r[2225]!, [_1])
    }
    public var Notification_CallMissed: String { return self._s[2226]! }
    public var Channel_AdminLogFilter_EventsInfo: String { return self._s[2227]! }
    public var ChatAdmins_AdminLabel: String { return self._s[2229]! }
    public var KeyCommand_JumpToNextChat: String { return self._s[2230]! }
    public var Conversation_StopPollConfirmationTitle: String { return self._s[2232]! }
    public var ChangePhoneNumberCode_CodePlaceholder: String { return self._s[2233]! }
    public var Month_GenJune: String { return self._s[2234]! }
    public var Watch_Location_Current: String { return self._s[2235]! }
    public var Conversation_TitleMute: String { return self._s[2236]! }
    public func PUSH_CHANNEL_MESSAGE_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2237]!, self._r[2237]!, [_1])
    }
    public var GroupInfo_DeleteAndExit: String { return self._s[2238]! }
    public func Conversation_Moderate_DeleteAllMessages(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2239]!, self._r[2239]!, [_0])
    }
    public var Call_ReportPlaceholder: String { return self._s[2240]! }
    public var MaskStickerSettings_Info: String { return self._s[2241]! }
    public func GroupInfo_AddParticipantConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2242]!, self._r[2242]!, [_0])
    }
    public var Checkout_NewCard_PostcodeTitle: String { return self._s[2243]! }
    public var Passport_Address_RegionPlaceholder: String { return self._s[2245]! }
    public var Contacts_ShareTelegram: String { return self._s[2246]! }
    public var EnterPasscode_EnterNewPasscodeNew: String { return self._s[2247]! }
    public var Channel_ErrorAccessDenied: String { return self._s[2248]! }
    public var Stickers_GroupChooseStickerPack: String { return self._s[2250]! }
    public var Call_ConnectionErrorTitle: String { return self._s[2251]! }
    public var UserInfo_NotificationsEnable: String { return self._s[2252]! }
    public var Tour_Text4: String { return self._s[2255]! }
    public var WallpaperSearch_Recent: String { return self._s[2256]! }
    public var Profile_MessageLifetime2s: String { return self._s[2258]! }
    public var Notification_MessageLifetime2s: String { return self._s[2259]! }
    public func Time_PreciseDate_m10(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2260]!, self._r[2260]!, [_1, _2, _3])
    }
    public var Cache_ClearCache: String { return self._s[2261]! }
    public var AutoNightTheme_UpdateLocation: String { return self._s[2262]! }
    public var Permissions_NotificationsUnreachableText_v0: String { return self._s[2263]! }
    public func Channel_AdminLog_MessageChangedGroupUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2267]!, self._r[2267]!, [_0])
    }
    public var Channel_AdminLog_EmptyFilterTitle: String { return self._s[2269]! }
    public var SocksProxySetup_TypeSocks: String { return self._s[2270]! }
    public var AutoNightTheme_Title: String { return self._s[2271]! }
    public var InstantPage_FeedbackButton: String { return self._s[2272]! }
    public var Passport_FieldAddress: String { return self._s[2273]! }
    public var Month_ShortMarch: String { return self._s[2274]! }
    public func PUSH_MESSAGE_INVOICE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2275]!, self._r[2275]!, [_1, _2])
    }
    public var SocksProxySetup_UsernamePlaceholder: String { return self._s[2276]! }
    public var Conversation_ShareInlineBotLocationConfirmation: String { return self._s[2277]! }
    public var Passport_FloodError: String { return self._s[2278]! }
    public var SecretGif_Title: String { return self._s[2279]! }
    public var Passport_Language_th: String { return self._s[2281]! }
    public var Passport_Address_Address: String { return self._s[2282]! }
    public var Login_InvalidLastNameError: String { return self._s[2283]! }
    public var Notifications_InAppNotificationsPreview: String { return self._s[2284]! }
    public var Notifications_PermissionsUnreachableTitle: String { return self._s[2285]! }
    public var ShareMenu_Send: String { return self._s[2286]! }
    public var WallpaperSearch_ColorYellow: String { return self._s[2288]! }
    public var Month_GenNovember: String { return self._s[2290]! }
    public var Checkout_Email: String { return self._s[2292]! }
    public var NotificationsSound_Tritone: String { return self._s[2293]! }
    public var StickerPacksSettings_ManagingHelp: String { return self._s[2295]! }
    public func PUSH_PINNED_ROUND(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2298]!, self._r[2298]!, [_1])
    }
    public var ChangePhoneNumberNumber_Help: String { return self._s[2299]! }
    public func Checkout_LiabilityAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2300]!, self._r[2300]!, [_1, _1, _1, _2])
    }
    public var DialogList_You: String { return self._s[2301]! }
    public var MediaPicker_Send: String { return self._s[2304]! }
    public var Call_AudioRouteSpeaker: String { return self._s[2305]! }
    public var Watch_UserInfo_Title: String { return self._s[2306]! }
    public var Appearance_AccentColor: String { return self._s[2307]! }
    public func Login_EmailPhoneSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2308]!, self._r[2308]!, [_0])
    }
    public var Permissions_ContactsAllowInSettings_v0: String { return self._s[2309]! }
    public func PUSH_CHANNEL_MESSAGE_GAME(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2310]!, self._r[2310]!, [_1, _2])
    }
    public var Conversation_ClousStorageInfo_Description2: String { return self._s[2311]! }
    public var WebSearch_RecentClearConfirmation: String { return self._s[2312]! }
    public var Notification_CallOutgoing: String { return self._s[2313]! }
    public var PrivacySettings_PasscodeAndFaceId: String { return self._s[2314]! }
    public var Call_RecordingDisabledMessage: String { return self._s[2315]! }
    public var PrivacyLastSeenSettings_CustomHelp: String { return self._s[2316]! }
    public var Channel_EditAdmin_PermissionAddAdmins: String { return self._s[2317]! }
    public var Date_DialogDateFormat: String { return self._s[2318]! }
    public var WallpaperColors_SetCustomColor: String { return self._s[2319]! }
    public var Notifications_InAppNotifications: String { return self._s[2320]! }
    public func Channel_Management_RemovedBy(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2321]!, self._r[2321]!, [_0])
    }
    public func Settings_ApplyProxyAlert(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2322]!, self._r[2322]!, [_1, _2])
    }
    public var NewContact_Title: String { return self._s[2323]! }
    public var Conversation_ViewContactDetails: String { return self._s[2324]! }
    public func PUSH_CHANNEL_MESSAGE_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2326]!, self._r[2326]!, [_1])
    }
    public var Checkout_NewCard_CardholderNameTitle: String { return self._s[2327]! }
    public var Passport_Identity_ExpiryDateNone: String { return self._s[2328]! }
    public var PrivacySettings_Title: String { return self._s[2329]! }
    public var Conversation_SilentBroadcastTooltipOff: String { return self._s[2332]! }
    public var GroupRemoved_UsersSectionTitle: String { return self._s[2333]! }
    public var Contacts_PhoneNumber: String { return self._s[2334]! }
    public var Map_ShowPlaces: String { return self._s[2336]! }
    public var ChatAdmins_Title: String { return self._s[2337]! }
    public var InstantPage_Reference: String { return self._s[2339]! }
    public func PUSH_CHAT_MESSAGE_FWD(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2340]!, self._r[2340]!, [_1, _2])
    }
    public var Camera_FlashOff: String { return self._s[2341]! }
    public var Watch_UserInfo_Block: String { return self._s[2342]! }
    public var ChatSettings_Stickers: String { return self._s[2343]! }
    public var ChatSettings_DownloadInBackground: String { return self._s[2344]! }
    public func UserInfo_BlockConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2345]!, self._r[2345]!, [_0])
    }
    public var Settings_ViewPhoto: String { return self._s[2346]! }
    public var Login_CheckOtherSessionMessages: String { return self._s[2347]! }
    public var AutoDownloadSettings_Cellular: String { return self._s[2348]! }
    public func Target_InviteToGroupConfirmation(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2350]!, self._r[2350]!, [_0])
    }
    public var Privacy_DeleteDrafts: String { return self._s[2351]! }
    public var Wallpaper_SetCustomBackgroundInfo: String { return self._s[2352]! }
    public func LastSeen_AtDate(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2353]!, self._r[2353]!, [_0])
    }
    public var DialogList_SavedMessagesHelp: String { return self._s[2354]! }
    public var DialogList_SavedMessages: String { return self._s[2355]! }
    public var GroupInfo_UpgradeButton: String { return self._s[2356]! }
    public var DialogList_Pin: String { return self._s[2357]! }
    public func ForwardedAuthors2(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2358]!, self._r[2358]!, [_0, _1])
    }
    public func Login_PhoneGenericEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2359]!, self._r[2359]!, [_0])
    }
    public var Notification_Exceptions_AlwaysOn: String { return self._s[2360]! }
    public var UserInfo_NotificationsDisable: String { return self._s[2361]! }
    public var Paint_Outlined: String { return self._s[2362]! }
    public var Activity_PlayingGame: String { return self._s[2363]! }
    public var SearchImages_NoImagesFound: String { return self._s[2364]! }
    public var SocksProxySetup_ProxyType: String { return self._s[2365]! }
    public var AppleWatch_ReplyPresetsHelp: String { return self._s[2367]! }
    public var Settings_AppLanguage: String { return self._s[2368]! }
    public var TwoStepAuth_ResetAccountHelp: String { return self._s[2369]! }
    public var Common_ChoosePhoto: String { return self._s[2370]! }
    public var CallFeedback_ReasonEcho: String { return self._s[2371]! }
    public func PUSH_PINNED_AUDIO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2372]!, self._r[2372]!, [_1])
    }
    public var Privacy_Calls_AlwaysAllow: String { return self._s[2373]! }
    public var Activity_UploadingVideo: String { return self._s[2374]! }
    public var ChannelInfo_DeleteChannelConfirmation: String { return self._s[2375]! }
    public var NetworkUsageSettings_Wifi: String { return self._s[2376]! }
    public var Channel_BanUser_PermissionReadMessages: String { return self._s[2377]! }
    public var Checkout_PayWithTouchId: String { return self._s[2378]! }
    public var Wallpaper_ResetWallpapersConfirmation: String { return self._s[2379]! }
    public func PUSH_LOCKED_MESSAGE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2381]!, self._r[2381]!, [_1])
    }
    public var Notifications_ExceptionsNone: String { return self._s[2382]! }
    public func Message_ForwardedMessageShort(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2383]!, self._r[2383]!, [_0])
    }
    public func PUSH_PINNED_GEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2384]!, self._r[2384]!, [_1])
    }
    public var AuthSessions_IncompleteAttempts: String { return self._s[2386]! }
    public var Passport_Address_Region: String { return self._s[2389]! }
    public var ChatList_DeleteChat: String { return self._s[2390]! }
    public var PhotoEditor_TiltShift: String { return self._s[2391]! }
    public var Settings_FAQ_URL: String { return self._s[2392]! }
    public var Passport_Language_sl: String { return self._s[2393]! }
    public var Settings_PrivacySettings: String { return self._s[2395]! }
    public var SharedMedia_TitleLink: String { return self._s[2396]! }
    public var Passport_Identity_TypePassportUploadScan: String { return self._s[2397]! }
    public var Settings_SetProfilePhoto: String { return self._s[2398]! }
    public var Channel_About_Help: String { return self._s[2399]! }
    public var Contacts_PermissionsEnable: String { return self._s[2400]! }
    public var AttachmentMenu_SendAsFiles: String { return self._s[2401]! }
    public var CallFeedback_ReasonInterruption: String { return self._s[2403]! }
    public var Passport_Address_AddTemporaryRegistration: String { return self._s[2404]! }
    public var PrivacySettings_DeleteAccountTitle: String { return self._s[2405]! }
    public var AccessDenied_VideoMessageCamera: String { return self._s[2407]! }
    public var Map_OpenInYandexMaps: String { return self._s[2409]! }
    public var PhotoEditor_SaturationTool: String { return self._s[2410]! }
    public func PUSH_MESSAGE_STICKER(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2411]!, self._r[2411]!, [_1, _2])
    }
    public var Notification_Exceptions_NewException_NotificationHeader: String { return self._s[2412]! }
    public var Appearance_TextSize: String { return self._s[2413]! }
    public func LOCAL_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2414]!, self._r[2414]!, [_1, "\(_2)"])
    }
    public var Channel_Username_InvalidTooShort: String { return self._s[2416]! }
    public func PUSH_CHAT_MESSAGE_GAME(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2417]!, self._r[2417]!, [_1, _2, _3])
    }
    public var Passport_PassportInformation: String { return self._s[2420]! }
    public var WatchRemote_AlertTitle: String { return self._s[2421]! }
    public var Privacy_GroupsAndChannels_NeverAllow: String { return self._s[2422]! }
    public var ConvertToSupergroup_HelpText: String { return self._s[2424]! }
    public func Time_MonthOfYear_m7(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2425]!, self._r[2425]!, [_0])
    }
    public func PUSH_PHONE_CALL_REQUEST(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2426]!, self._r[2426]!, [_1])
    }
    public var Privacy_GroupsAndChannels_CustomHelp: String { return self._s[2427]! }
    public var TwoStepAuth_RecoveryCodeInvalid: String { return self._s[2429]! }
    public var AccessDenied_CameraDisabled: String { return self._s[2430]! }
    public func Channel_Username_UsernameIsAvailable(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2431]!, self._r[2431]!, [_0])
    }
    public var PhotoEditor_ContrastTool: String { return self._s[2434]! }
    public func PUSH_PINNED_DOC(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2435]!, self._r[2435]!, [_1])
    }
    public var DialogList_Draft: String { return self._s[2436]! }
    public var Privacy_TopPeersDelete: String { return self._s[2438]! }
    public var LoginPassword_PasswordPlaceholder: String { return self._s[2439]! }
    public var Passport_Identity_TypeIdentityCardUploadScan: String { return self._s[2440]! }
    public var WebSearch_RecentSectionClear: String { return self._s[2441]! }
    public var Watch_ChatList_NoConversationsTitle: String { return self._s[2443]! }
    public var Common_Done: String { return self._s[2445]! }
    public var AuthSessions_EmptyText: String { return self._s[2446]! }
    public var Conversation_ShareBotContactConfirmation: String { return self._s[2447]! }
    public var Tour_Title5: String { return self._s[2448]! }
    public func Map_DirectionsDriveEta(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2449]!, self._r[2449]!, [_0])
    }
    public var ApplyLanguage_UnsufficientDataTitle: String { return self._s[2450]! }
    public var Conversation_LinkDialogSave: String { return self._s[2451]! }
    public var GroupInfo_ActionRestrict: String { return self._s[2452]! }
    public var Checkout_Title: String { return self._s[2453]! }
    public var Channel_AdminLog_CanChangeInfo: String { return self._s[2456]! }
    public var Notification_RenamedGroup: String { return self._s[2457]! }
    public var Checkout_PayWithFaceId: String { return self._s[2458]! }
    public var Channel_BanList_BlockedTitle: String { return self._s[2459]! }
    public var Checkout_WebConfirmation_Title: String { return self._s[2461]! }
    public var Notifications_MessageNotificationsAlert: String { return self._s[2462]! }
    public var Profile_AddToExisting: String { return self._s[2464]! }
    public func Profile_CreateEncryptedChatOutdatedError(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2465]!, self._r[2465]!, [_0, _1])
    }
    public var Cache_Files: String { return self._s[2467]! }
    public var Permissions_PrivacyPolicy: String { return self._s[2468]! }
    public var SocksProxySetup_ConnectAndSave: String { return self._s[2469]! }
    public var UserInfo_NotificationsDefaultDisabled: String { return self._s[2470]! }
    public var Calls_NoCallsPlaceholder: String { return self._s[2473]! }
    public var Channel_Username_RevokeExistingUsernamesInfo: String { return self._s[2474]! }
    public var Notifications_ExceptionsGroupPlaceholder: String { return self._s[2476]! }
    public func PUSH_CHAT_MESSAGE_INVOICE(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2477]!, self._r[2477]!, [_1, _2, _3])
    }
    public var Passport_FieldAddressHelp: String { return self._s[2478]! }
    public var Privacy_GroupsAndChannels_InviteToChannelMultipleError: String { return self._s[2479]! }
    public func Login_TermsOfService_ProceedBot(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2480]!, self._r[2480]!, [_0])
    }
    public var Channel_AdminLog_EmptyTitle: String { return self._s[2481]! }
    public var Privacy_Calls_NeverAllow_Title: String { return self._s[2483]! }
    public var Login_UnknownError: String { return self._s[2484]! }
    public var Group_UpgradeNoticeText2: String { return self._s[2486]! }
    public var Watch_Compose_AddContact: String { return self._s[2487]! }
    public var Web_Error: String { return self._s[2488]! }
    public var Profile_MessageLifetime1h: String { return self._s[2489]! }
    public var CheckoutInfo_ReceiverInfoEmailPlaceholder: String { return self._s[2490]! }
    public var Channel_Username_CheckingUsername: String { return self._s[2491]! }
    public var CallFeedback_ReasonSilentRemote: String { return self._s[2492]! }
    public var Channel_AboutItem: String { return self._s[2493]! }
    public var Privacy_GroupsAndChannels_AlwaysAllow_Placeholder: String { return self._s[2495]! }
    public var GroupInfo_SharedMedia: String { return self._s[2496]! }
    public func Channel_AdminLog_MessagePromotedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2497]!, self._r[2497]!, [_1])
    }
    public var Call_PhoneCallInProgressMessage: String { return self._s[2498]! }
    public var GroupInfo_InviteLink_RevokeAlert_Text: String { return self._s[2499]! }
    public var Conversation_SearchByName_Placeholder: String { return self._s[2500]! }
    public var CreatePoll_AddOption: String { return self._s[2501]! }
    public var GroupInfo_Permissions_SearchPlaceholder: String { return self._s[2502]! }
    public var Group_UpgradeNoticeHeader: String { return self._s[2503]! }
    public var Channel_Management_AddModerator: String { return self._s[2504]! }
    public var StickerPacksSettings_ShowStickersButton: String { return self._s[2505]! }
    public var NotificationsSound_Hello: String { return self._s[2506]! }
    public var SocksProxySetup_SavedProxies: String { return self._s[2507]! }
    public var Channel_Stickers_Placeholder: String { return self._s[2509]! }
    public func Login_EmailCodeBody(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2510]!, self._r[2510]!, [_0])
    }
    public var PrivacyPolicy_DeclineDeclineAndDelete: String { return self._s[2511]! }
    public var Channel_Management_AddModeratorHelp: String { return self._s[2512]! }
    public var ContactInfo_BirthdayLabel: String { return self._s[2513]! }
    public var ChangePhoneNumberCode_RequestingACall: String { return self._s[2514]! }
    public var AutoDownloadSettings_Channels: String { return self._s[2515]! }
    public var Passport_Language_mn: String { return self._s[2516]! }
    public var Notifications_ResetAllNotificationsHelp: String { return self._s[2519]! }
    public var Passport_Language_ja: String { return self._s[2521]! }
    public var Settings_About_Title: String { return self._s[2522]! }
    public var Settings_NotificationsAndSounds: String { return self._s[2523]! }
    public var ChannelInfo_DeleteGroup: String { return self._s[2524]! }
    public var Settings_BlockedUsers: String { return self._s[2525]! }
    public func Time_MonthOfYear_m4(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2526]!, self._r[2526]!, [_0])
    }
    public var Passport_Address_AddResidentialAddress: String { return self._s[2527]! }
    public var Channel_Username_Title: String { return self._s[2528]! }
    public func Notification_RemovedGroupPhoto(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2529]!, self._r[2529]!, [_0])
    }
    public var AttachmentMenu_File: String { return self._s[2531]! }
    public var AppleWatch_Title: String { return self._s[2532]! }
    public var Activity_RecordingVideoMessage: String { return self._s[2533]! }
    public var Weekday_Saturday: String { return self._s[2534]! }
    public var WallpaperPreview_SwipeColorsTopText: String { return self._s[2535]! }
    public var Profile_CreateEncryptedChatError: String { return self._s[2536]! }
    public var Common_Next: String { return self._s[2538]! }
    public var Channel_Stickers_YourStickers: String { return self._s[2540]! }
    public var Call_AudioRouteHeadphones: String { return self._s[2541]! }
    public var TwoStepAuth_EnterPasswordForgot: String { return self._s[2543]! }
    public var Watch_Contacts_NoResults: String { return self._s[2545]! }
    public var PhotoEditor_TintTool: String { return self._s[2548]! }
    public var LoginPassword_ResetAccount: String { return self._s[2550]! }
    public var Settings_SavedMessages: String { return self._s[2551]! }
    public var StickerPack_Add: String { return self._s[2552]! }
    public var Your_cards_number_is_invalid: String { return self._s[2553]! }
    public var Checkout_TotalAmount: String { return self._s[2554]! }
    public func ChangePhoneNumberCode_CallTimer(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2555]!, self._r[2555]!, [_0])
    }
    public func GroupPermission_AddedInfo(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2556]!, self._r[2556]!, [_1, _2])
    }
    public var ChatSettings_ConnectionType_UseSocks5: String { return self._s[2557]! }
    public func PUSH_CHAT_PHOTO_EDITED(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2559]!, self._r[2559]!, [_1, _2])
    }
    public func Conversation_RestrictedTextTimed(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2560]!, self._r[2560]!, [_0])
    }
    public var GroupInfo_InviteLink_ShareLink: String { return self._s[2561]! }
    public var StickerPack_Share: String { return self._s[2562]! }
    public var Passport_DeleteAddress: String { return self._s[2563]! }
    public var Settings_Passport: String { return self._s[2564]! }
    public var SharedMedia_EmptyFilesText: String { return self._s[2565]! }
    public var Conversation_DeleteMessagesForMe: String { return self._s[2566]! }
    public var PasscodeSettings_AutoLock_IfAwayFor_1hour: String { return self._s[2567]! }
    public var Contacts_PermissionsText: String { return self._s[2568]! }
    public var Group_Setup_HistoryVisible: String { return self._s[2569]! }
    public var Passport_Address_AddRentalAgreement: String { return self._s[2571]! }
    public var SocksProxySetup_Title: String { return self._s[2572]! }
    public var Notification_Mute1h: String { return self._s[2573]! }
    public func Passport_Email_CodeHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2574]!, self._r[2574]!, [_0])
    }
    public func PUSH_PINNED_GEOLIVE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2575]!, self._r[2575]!, [_1])
    }
    public var FastTwoStepSetup_PasswordSection: String { return self._s[2576]! }
    public var NetworkUsageSettings_ResetStatsConfirmation: String { return self._s[2579]! }
    public var InfoPlist_NSFaceIDUsageDescription: String { return self._s[2581]! }
    public var DialogList_NoMessagesText: String { return self._s[2582]! }
    public var Privacy_ContactsResetConfirmation: String { return self._s[2583]! }
    public var Privacy_Calls_P2PHelp: String { return self._s[2584]! }
    public var Your_cards_expiration_year_is_invalid: String { return self._s[2586]! }
    public var Common_TakePhotoOrVideo: String { return self._s[2587]! }
    public var Call_StatusBusy: String { return self._s[2588]! }
    public var Conversation_PinnedMessage: String { return self._s[2589]! }
    public var AutoDownloadSettings_VoiceMessagesTitle: String { return self._s[2590]! }
    public var TwoStepAuth_SetupPasswordConfirmFailed: String { return self._s[2591]! }
    public var AppleWatch_ReplyPresets: String { return self._s[2592]! }
    public var Passport_DiscardMessageDescription: String { return self._s[2594]! }
    public var Login_NetworkError: String { return self._s[2595]! }
    public func Notification_PinnedRoundMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2596]!, self._r[2596]!, [_0])
    }
    public func Channel_AdminLog_MessageRemovedChannelUsername(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2597]!, self._r[2597]!, [_0])
    }
    public var SocksProxySetup_PasswordPlaceholder: String { return self._s[2598]! }
    public var Login_ResetAccountProtected_LimitExceeded: String { return self._s[2600]! }
    public func Watch_LastSeen_YesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2602]!, self._r[2602]!, [_0])
    }
    public var Call_ConnectionErrorMessage: String { return self._s[2603]! }
    public var Compose_GroupTokenListPlaceholder: String { return self._s[2605]! }
    public var ConversationMedia_Title: String { return self._s[2606]! }
    public var EncryptionKey_Title: String { return self._s[2608]! }
    public var TwoStepAuth_EnterPasswordTitle: String { return self._s[2609]! }
    public var Notification_Exceptions_AddException: String { return self._s[2610]! }
    public var Profile_MessageLifetime1m: String { return self._s[2611]! }
    public func Channel_AdminLog_MessageUnkickedName(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2612]!, self._r[2612]!, [_1])
    }
    public var Month_GenMay: String { return self._s[2613]! }
    public func LiveLocationUpdated_TodayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2614]!, self._r[2614]!, [_0])
    }
    public var ChannelMembers_WhoCanAddMembersAllHelp: String { return self._s[2615]! }
    public var Conversation_EmptyPlaceholder: String { return self._s[2617]! }
    public var Passport_Address_AddPassportRegistration: String { return self._s[2618]! }
    public var Notifications_ChannelNotificationsAlert: String { return self._s[2619]! }
    public var Camera_TapAndHoldForVideo: String { return self._s[2620]! }
    public var Channel_JoinChannel: String { return self._s[2622]! }
    public var Appearance_Animations: String { return self._s[2625]! }
    public func Notification_MessageLifetimeChanged(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2626]!, self._r[2626]!, [_1, _2])
    }
    public var Stickers_GroupStickers: String { return self._s[2628]! }
    public var ConvertToSupergroup_HelpTitle: String { return self._s[2630]! }
    public var Passport_Address_Street: String { return self._s[2631]! }
    public var Conversation_AddContact: String { return self._s[2632]! }
    public var Login_PhonePlaceholder: String { return self._s[2633]! }
    public var Channel_Members_InviteLink: String { return self._s[2635]! }
    public var Bot_Stop: String { return self._s[2636]! }
    public var Notification_PassportValueAddress: String { return self._s[2638]! }
    public var Month_ShortJuly: String { return self._s[2639]! }
    public var Passport_Address_TypeTemporaryRegistrationUploadScan: String { return self._s[2640]! }
    public var Channel_AdminLog_BanSendMedia: String { return self._s[2641]! }
    public var Passport_Identity_ReverseSide: String { return self._s[2642]! }
    public var Watch_Stickers_Recents: String { return self._s[2645]! }
    public var PrivacyLastSeenSettings_EmpryUsersPlaceholder: String { return self._s[2647]! }
    public var Map_SendThisLocation: String { return self._s[2648]! }
    public func Time_MonthOfYear_m1(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2649]!, self._r[2649]!, [_0])
    }
    public func InviteText_SingleContact(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2650]!, self._r[2650]!, [_0])
    }
    public var ConvertToSupergroup_Note: String { return self._s[2651]! }
    public func FileSize_MB(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2652]!, self._r[2652]!, [_0])
    }
    public var NetworkUsageSettings_GeneralDataSection: String { return self._s[2653]! }
    public func Compatibility_SecretMediaVersionTooLow(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2654]!, self._r[2654]!, [_0, _1])
    }
    public var Login_CallRequestState3: String { return self._s[2656]! }
    public var Wallpaper_SearchShort: String { return self._s[2657]! }
    public var PasscodeSettings_UnlockWithFaceId: String { return self._s[2659]! }
    public func PUSH_CHAT_MESSAGE_GEOLIVE(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2660]!, self._r[2660]!, [_1, _2])
    }
    public var Channel_AdminLogFilter_Title: String { return self._s[2661]! }
    public var Notifications_GroupNotificationsExceptions: String { return self._s[2665]! }
    public func FileSize_B(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2666]!, self._r[2666]!, [_0])
    }
    public var Passport_CorrectErrors: String { return self._s[2667]! }
    public func Channel_MessageTitleUpdated(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2668]!, self._r[2668]!, [_0])
    }
    public var Map_SendMyCurrentLocation: String { return self._s[2669]! }
    public func PUSH_PINNED_CONTACT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2670]!, self._r[2670]!, [_1])
    }
    public var SharedMedia_SearchNoResults: String { return self._s[2671]! }
    public var Permissions_NotificationsText_v0: String { return self._s[2672]! }
    public var LoginPassword_FloodError: String { return self._s[2673]! }
    public var Group_Setup_HistoryHiddenHelp: String { return self._s[2675]! }
    public func TwoStepAuth_PendingEmailHelp(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2676]!, self._r[2676]!, [_0])
    }
    public var Passport_Language_bn: String { return self._s[2677]! }
    public func DialogList_SingleUploadingPhotoSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2678]!, self._r[2678]!, [_0])
    }
    public func Notification_PinnedAudioMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2679]!, self._r[2679]!, [_0])
    }
    public func Channel_AdminLog_MessageChangedGroupStickerPack(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2680]!, self._r[2680]!, [_0])
    }
    public var GroupInfo_InvitationLinkGroupFull: String { return self._s[2683]! }
    public var Group_EditAdmin_PermissionChangeInfo: String { return self._s[2685]! }
    public var Contacts_PermissionsAllow: String { return self._s[2686]! }
    public var ReportPeer_ReasonCopyright: String { return self._s[2687]! }
    public var Channel_EditAdmin_PermissinAddAdminOn: String { return self._s[2688]! }
    public var WallpaperPreview_Pattern: String { return self._s[2689]! }
    public var Paint_Duplicate: String { return self._s[2690]! }
    public var Passport_Address_Country: String { return self._s[2691]! }
    public var Notification_RenamedChannel: String { return self._s[2693]! }
    public var CheckoutInfo_ErrorPostcodeInvalid: String { return self._s[2694]! }
    public var Group_MessagePhotoUpdated: String { return self._s[2695]! }
    public var Channel_BanUser_PermissionSendMedia: String { return self._s[2696]! }
    public var Conversation_ContextMenuBan: String { return self._s[2697]! }
    public var TwoStepAuth_EmailSent: String { return self._s[2698]! }
    public var MessagePoll_NoVotes: String { return self._s[2699]! }
    public var Passport_Language_is: String { return self._s[2700]! }
    public var Tour_Text5: String { return self._s[2702]! }
    public func Call_GroupFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2704]!, self._r[2704]!, [_1, _2])
    }
    public var Undo_SecretChatDeleted: String { return self._s[2705]! }
    public var SocksProxySetup_ShareQRCode: String { return self._s[2706]! }
    public var Paint_Edit: String { return self._s[2708]! }
    public var Undo_DeletedGroup: String { return self._s[2711]! }
    public var LoginPassword_ForgotPassword: String { return self._s[2712]! }
    public var GroupInfo_GroupNamePlaceholder: String { return self._s[2713]! }
    public func Notification_Kicked(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2714]!, self._r[2714]!, [_0, _1])
    }
    public var Conversation_InputTextCaptionPlaceholder: String { return self._s[2715]! }
    public var AutoDownloadSettings_VideoMessagesTitle: String { return self._s[2716]! }
    public var Passport_Language_uz: String { return self._s[2717]! }
    public var Conversation_PinMessageAlertGroup: String { return self._s[2718]! }
    public var Map_StopLiveLocation: String { return self._s[2720]! }
    public var PasscodeSettings_Help: String { return self._s[2722]! }
    public var NotificationsSound_Input: String { return self._s[2723]! }
    public var Share_Title: String { return self._s[2726]! }
    public var Login_TermsOfServiceAgree: String { return self._s[2727]! }
    public var Compose_NewEncryptedChatTitle: String { return self._s[2728]! }
    public var Channel_AdminLog_TitleSelectedEvents: String { return self._s[2729]! }
    public var Channel_EditAdmin_PermissionEditMessages: String { return self._s[2730]! }
    public var EnterPasscode_EnterTitle: String { return self._s[2731]! }
    public func Call_PrivacyErrorMessage(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2732]!, self._r[2732]!, [_0])
    }
    public var Settings_CopyPhoneNumber: String { return self._s[2733]! }
    public var NotificationsSound_Keys: String { return self._s[2734]! }
    public func Call_ParticipantVersionOutdatedError(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2735]!, self._r[2735]!, [_0])
    }
    public var Notification_MessageLifetime1w: String { return self._s[2736]! }
    public var Message_Video: String { return self._s[2737]! }
    public func PUSH_CHANNEL_MESSAGE_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2738]!, self._r[2738]!, [_1])
    }
    public func Notification_JoinedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2741]!, self._r[2741]!, [_0])
    }
    public func PrivacySettings_LastSeenContactsPlus(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2742]!, self._r[2742]!, [_0])
    }
    public var Passport_Language_mk: String { return self._s[2743]! }
    public var CreatePoll_CancelConfirmation: String { return self._s[2744]! }
    public var Conversation_SilentBroadcastTooltipOn: String { return self._s[2746]! }
    public var PrivacyPolicy_Decline: String { return self._s[2747]! }
    public var Passport_Identity_DoesNotExpire: String { return self._s[2748]! }
    public var Channel_AdminLogFilter_EventsRestrictions: String { return self._s[2749]! }
    public var Permissions_SiriAllow_v0: String { return self._s[2751]! }
    public func LOCAL_CHAT_MESSAGE_FWDS(_ _1: String, _ _2: Int) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2752]!, self._r[2752]!, [_1, "\(_2)"])
    }
    public func Notification_RenamedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2753]!, self._r[2753]!, [_0])
    }
    public var Paint_Regular: String { return self._s[2754]! }
    public var ChatSettings_AutoDownloadReset: String { return self._s[2755]! }
    public var SocksProxySetup_ShareLink: String { return self._s[2756]! }
    public var BlockedUsers_SelectUserTitle: String { return self._s[2757]! }
    public var GroupInfo_InviteByLink: String { return self._s[2759]! }
    public var MessageTimer_Custom: String { return self._s[2760]! }
    public var UserInfo_NotificationsDefaultEnabled: String { return self._s[2761]! }
    public var Passport_Address_TypeTemporaryRegistration: String { return self._s[2763]! }
    public var Channel_Username_InvalidTaken: String { return self._s[2764]! }
    public var Conversation_ClousStorageInfo_Description3: String { return self._s[2765]! }
    public var Settings_ChatBackground: String { return self._s[2766]! }
    public var Channel_Subscribers_Title: String { return self._s[2767]! }
    public var ApplyLanguage_ChangeLanguageTitle: String { return self._s[2768]! }
    public var Watch_ConnectionDescription: String { return self._s[2769]! }
    public var Wallpaper_ResetWallpapers: String { return self._s[2773]! }
    public var EditProfile_Title: String { return self._s[2774]! }
    public var NotificationsSound_Bamboo: String { return self._s[2776]! }
    public var Channel_AdminLog_MessagePreviousMessage: String { return self._s[2778]! }
    public var Login_SmsRequestState2: String { return self._s[2779]! }
    public var Passport_Language_ar: String { return self._s[2780]! }
    public var Conversation_MessageDialogEdit: String { return self._s[2781]! }
    public func PUSH_AUTH_UNKNOWN(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2782]!, self._r[2782]!, [_1])
    }
    public var Common_Close: String { return self._s[2783]! }
    public func Channel_AdminLog_MessageToggleInvitesOff(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2787]!, self._r[2787]!, [_0])
    }
    public var UserInfo_About_Placeholder: String { return self._s[2788]! }
    public func Conversation_FileHowToText(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2789]!, self._r[2789]!, [_0])
    }
    public var GroupInfo_Permissions_SectionTitle: String { return self._s[2790]! }
    public var Channel_Info_Banned: String { return self._s[2792]! }
    public func Time_MonthOfYear_m11(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2793]!, self._r[2793]!, [_0])
    }
    public var Passport_Language_my: String { return self._s[2794]! }
    public var Group_Setup_BasicHistoryHiddenHelp: String { return self._s[2795]! }
    public func Time_PreciseDate_m9(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2796]!, self._r[2796]!, [_1, _2, _3])
    }
    public var Preview_CopyAddress: String { return self._s[2797]! }
    public func DialogList_SinglePlayingGameSuffix(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2798]!, self._r[2798]!, [_0])
    }
    public var KeyCommand_JumpToPreviousChat: String { return self._s[2799]! }
    public var UserInfo_BotSettings: String { return self._s[2800]! }
    public var LiveLocation_MenuStopAll: String { return self._s[2802]! }
    public var Passport_PasswordCreate: String { return self._s[2803]! }
    public var StickerSettings_MaskContextInfo: String { return self._s[2804]! }
    public var Message_PinnedLocationMessage: String { return self._s[2805]! }
    public var Map_Satellite: String { return self._s[2806]! }
    public var Watch_Message_Unsupported: String { return self._s[2807]! }
    public var Username_TooManyPublicUsernamesError: String { return self._s[2808]! }
    public var TwoStepAuth_EnterPasswordInvalid: String { return self._s[2809]! }
    public func Notification_PinnedTextMessage(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2810]!, self._r[2810]!, [_0, _1])
    }
    public var Notifications_ChannelNotificationsHelp: String { return self._s[2811]! }
    public var Privacy_Calls_P2PContacts: String { return self._s[2812]! }
    public var NotificationsSound_None: String { return self._s[2813]! }
    public var AccessDenied_VoiceMicrophone: String { return self._s[2815]! }
    public func ApplyLanguage_ChangeLanguageAlreadyActive(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2816]!, self._r[2816]!, [_1])
    }
    public var Cache_Indexing: String { return self._s[2817]! }
    public var DialogList_RecentTitlePeople: String { return self._s[2819]! }
    public var DialogList_EncryptionRejected: String { return self._s[2820]! }
    public var GroupInfo_Administrators: String { return self._s[2821]! }
    public var Passport_ScanPassportHelp: String { return self._s[2822]! }
    public var Application_Name: String { return self._s[2823]! }
    public var Channel_AdminLogFilter_ChannelEventsInfo: String { return self._s[2824]! }
    public var Passport_Identity_TranslationHelp: String { return self._s[2826]! }
    public func Notification_JoinedGroupByLink(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2827]!, self._r[2827]!, [_0])
    }
    public func DialogList_EncryptedChatStartedOutgoing(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2828]!, self._r[2828]!, [_0])
    }
    public var Channel_EditAdmin_PermissionDeleteMessages: String { return self._s[2829]! }
    public var Privacy_ChatsTitle: String { return self._s[2830]! }
    public var DialogList_ClearHistoryConfirmation: String { return self._s[2831]! }
    public var Watch_Suggestion_HoldOn: String { return self._s[2832]! }
    public var SocksProxySetup_RequiredCredentials: String { return self._s[2833]! }
    public var Passport_Address_TypeRentalAgreementUploadScan: String { return self._s[2834]! }
    public var TwoStepAuth_EmailSkipAlert: String { return self._s[2835]! }
    public var Channel_Setup_TypePublic: String { return self._s[2838]! }
    public func Channel_AdminLog_MessageToggleInvitesOn(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2839]!, self._r[2839]!, [_0])
    }
    public var Channel_TypeSetup_Title: String { return self._s[2841]! }
    public var Map_OpenInMaps: String { return self._s[2843]! }
    public func PUSH_PINNED_NOTEXT(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2844]!, self._r[2844]!, [_1])
    }
    public var NotificationsSound_Tremolo: String { return self._s[2846]! }
    public func Date_ChatDateHeaderYear(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2847]!, self._r[2847]!, [_1, _2, _3])
    }
    public var ConversationProfile_UnknownAddMemberError: String { return self._s[2848]! }
    public var Passport_PasswordHelp: String { return self._s[2849]! }
    public var Login_CodeExpiredError: String { return self._s[2850]! }
    public var Channel_EditAdmin_PermissionChangeInfo: String { return self._s[2851]! }
    public var Conversation_TitleUnmute: String { return self._s[2852]! }
    public var Passport_Identity_ScansHelp: String { return self._s[2853]! }
    public var Passport_Language_lo: String { return self._s[2854]! }
    public var Camera_FlashAuto: String { return self._s[2855]! }
    public var Common_Cancel: String { return self._s[2856]! }
    public var DialogList_SavedMessagesTooltip: String { return self._s[2857]! }
    public var TwoStepAuth_SetupPasswordTitle: String { return self._s[2858]! }
    public func PUSH_MESSAGE_FWD(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2859]!, self._r[2859]!, [_1])
    }
    public var Conversation_ReportSpamConfirmation: String { return self._s[2860]! }
    public var ChatSettings_Title: String { return self._s[2862]! }
    public var Passport_PasswordReset: String { return self._s[2863]! }
    public var SocksProxySetup_TypeNone: String { return self._s[2864]! }
    public var PhoneNumberHelp_Help: String { return self._s[2866]! }
    public var Checkout_EnterPassword: String { return self._s[2867]! }
    public var Share_AuthTitle: String { return self._s[2869]! }
    public var Activity_UploadingDocument: String { return self._s[2870]! }
    public var State_Connecting: String { return self._s[2871]! }
    public var Profile_MessageLifetime1w: String { return self._s[2872]! }
    public var Conversation_ContextMenuReport: String { return self._s[2873]! }
    public var CheckoutInfo_ReceiverInfoPhone: String { return self._s[2874]! }
    public var AutoNightTheme_ScheduledTo: String { return self._s[2875]! }
    public var AuthSessions_Terminate: String { return self._s[2876]! }
    public var Checkout_NewCard_CardholderNamePlaceholder: String { return self._s[2877]! }
    public var KeyCommand_JumpToPreviousUnreadChat: String { return self._s[2878]! }
    public var PhotoEditor_Set: String { return self._s[2879]! }
    public var EmptyGroupInfo_Title: String { return self._s[2880]! }
    public var Login_PadPhoneHelp: String { return self._s[2881]! }
    public var PrivacyPolicy_DeclineLastWarning: String { return self._s[2884]! }
    public var NotificationsSound_Complete: String { return self._s[2885]! }
    public var Group_Info_AdminLog: String { return self._s[2886]! }
    public var GroupPermission_NotAvailableInPublicGroups: String { return self._s[2887]! }
    public var Channel_AdminLog_InfoPanelAlertText: String { return self._s[2888]! }
    public var Conversation_Admin: String { return self._s[2890]! }
    public var Conversation_GifTooltip: String { return self._s[2891]! }
    public var Passport_NotLoggedInMessage: String { return self._s[2892]! }
    public var Profile_MessageLifetimeForever: String { return self._s[2893]! }
    public var SharedMedia_EmptyTitle: String { return self._s[2895]! }
    public var Channel_Edit_PrivatePublicLinkAlert: String { return self._s[2897]! }
    public var Username_Help: String { return self._s[2898]! }
    public var DialogList_LanguageTooltip: String { return self._s[2900]! }
    public var Map_LoadError: String { return self._s[2901]! }
    public var Login_PhoneNumberAlreadyAuthorized: String { return self._s[2902]! }
    public var Channel_AdminLog_AddMembers: String { return self._s[2903]! }
    public var Notification_Exceptions_NewException: String { return self._s[2904]! }
    public var TwoStepAuth_EmailTitle: String { return self._s[2905]! }
    public var WatchRemote_AlertText: String { return self._s[2906]! }
    public var ChatSettings_ConnectionType_Title: String { return self._s[2909]! }
    public var Passport_Address_CountryPlaceholder: String { return self._s[2910]! }
    public func DialogList_AwaitingEncryption(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2911]!, self._r[2911]!, [_0])
    }
    public func Time_PreciseDate_m6(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2912]!, self._r[2912]!, [_1, _2, _3])
    }
    public var Group_AdminLog_EmptyText: String { return self._s[2913]! }
    public var AccessDenied_VideoMicrophone: String { return self._s[2915]! }
    public var Conversation_ContextMenuStickerPackAdd: String { return self._s[2916]! }
    public var Cache_ClearNone: String { return self._s[2917]! }
    public var SocksProxySetup_FailedToConnect: String { return self._s[2918]! }
    public var Permissions_NotificationsTitle_v0: String { return self._s[2919]! }
    public func Channel_AdminLog_MessageEdited(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2920]!, self._r[2920]!, [_0])
    }
    public var Passport_Identity_Country: String { return self._s[2921]! }
    public func Notification_CreatedChat(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2922]!, self._r[2922]!, [_0])
    }
    public var AccessDenied_Settings: String { return self._s[2923]! }
    public var Passport_Address_TypeUtilityBillUploadScan: String { return self._s[2924]! }
    public var Month_ShortMay: String { return self._s[2925]! }
    public var Compose_NewGroup: String { return self._s[2926]! }
    public var Group_Setup_TypePrivate: String { return self._s[2928]! }
    public var Login_PadPhoneHelpTitle: String { return self._s[2930]! }
    public var Appearance_ThemeDayClassic: String { return self._s[2931]! }
    public var Channel_AdminLog_MessagePreviousCaption: String { return self._s[2932]! }
    public var Privacy_GroupsAndChannels_WhoCanAddMe: String { return self._s[2933]! }
    public var Conversation_typing: String { return self._s[2935]! }
    public var Paint_Masks: String { return self._s[2936]! }
    public var Username_InvalidTaken: String { return self._s[2937]! }
    public var Call_StatusNoAnswer: String { return self._s[2938]! }
    public var TwoStepAuth_EmailAddSuccess: String { return self._s[2939]! }
    public var Passport_Identity_Selfie: String { return self._s[2940]! }
    public var Login_InfoLastNamePlaceholder: String { return self._s[2941]! }
    public var Privacy_SecretChatsLinkPreviewsHelp: String { return self._s[2942]! }
    public var Conversation_ClearSecretHistory: String { return self._s[2943]! }
    public var NetworkUsageSettings_Title: String { return self._s[2945]! }
    public var Your_cards_security_code_is_invalid: String { return self._s[2947]! }
    public func Notification_LeftChannel(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2949]!, self._r[2949]!, [_0])
    }
    public func Call_CallInProgressMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2950]!, self._r[2950]!, [_1, _2])
    }
    public var SaveIncomingPhotosSettings_From: String { return self._s[2952]! }
    public var Map_LiveLocationTitle: String { return self._s[2953]! }
    public var Login_InfoAvatarAdd: String { return self._s[2954]! }
    public var Passport_Identity_FilesView: String { return self._s[2955]! }
    public var UserInfo_GenericPhoneLabel: String { return self._s[2956]! }
    public var Privacy_Calls_NeverAllow: String { return self._s[2957]! }
    public func Contacts_AddPhoneNumber(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2958]!, self._r[2958]!, [_0])
    }
    public var TwoStepAuth_ConfirmationText: String { return self._s[2959]! }
    public var ChatSettings_AutomaticVideoMessageDownload: String { return self._s[2960]! }
    public var Channel_AdminLogFilter_AdminsAll: String { return self._s[2961]! }
    public var Tour_Title2: String { return self._s[2962]! }
    public var Conversation_FileOpenIn: String { return self._s[2963]! }
    public var Checkout_ErrorPrecheckoutFailed: String { return self._s[2964]! }
    public var Wallpaper_Set: String { return self._s[2965]! }
    public var Passport_Identity_Translations: String { return self._s[2967]! }
    public func Channel_AdminLog_MessageChangedChannelAbout(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2968]!, self._r[2968]!, [_0])
    }
    public var Channel_LeaveChannel: String { return self._s[2969]! }
    public func PINNED_INVOICE(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2970]!, self._r[2970]!, [_1])
    }
    public var PhotoEditor_HighlightsTint: String { return self._s[2971]! }
    public var Passport_Email_Delete: String { return self._s[2972]! }
    public var Conversation_Mute: String { return self._s[2974]! }
    public var Channel_AdminLog_CanSendMessages: String { return self._s[2976]! }
    public func Notification_PassportValuesSentMessage(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2978]!, self._r[2978]!, [_1, _2])
    }
    public var Calls_CallTabDescription: String { return self._s[2979]! }
    public var Passport_Identity_NativeNameHelp: String { return self._s[2980]! }
    public var Common_No: String { return self._s[2981]! }
    public var Weekday_Sunday: String { return self._s[2982]! }
    public var Notification_Reply: String { return self._s[2983]! }
    public var Conversation_ViewMessage: String { return self._s[2984]! }
    public func Checkout_SavePasswordTimeoutAndFaceId(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2985]!, self._r[2985]!, [_0])
    }
    public func Map_LiveLocationPrivateDescription(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2986]!, self._r[2986]!, [_0])
    }
    public var Message_PinnedDocumentMessage: String { return self._s[2987]! }
    public var DialogList_TabTitle: String { return self._s[2989]! }
    public var Passport_FieldEmail: String { return self._s[2990]! }
    public var Conversation_UnpinMessageAlert: String { return self._s[2991]! }
    public var Passport_Address_TypeBankStatement: String { return self._s[2992]! }
    public var Passport_Identity_ExpiryDate: String { return self._s[2993]! }
    public var Privacy_Calls_P2P: String { return self._s[2994]! }
    public func CancelResetAccount_Success(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[2996]!, self._r[2996]!, [_0])
    }
    public var SocksProxySetup_UseForCallsHelp: String { return self._s[2997]! }
    public var EnterPasscode_ChangeTitle: String { return self._s[2998]! }
    public var Passport_InfoText: String { return self._s[2999]! }
    public var Checkout_NewCard_SaveInfoEnableHelp: String { return self._s[3000]! }
    public func Login_InvalidPhoneEmailSubject(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3001]!, self._r[3001]!, [_0])
    }
    public func Time_PreciseDate_m3(_ _1: String, _ _2: String, _ _3: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3002]!, self._r[3002]!, [_1, _2, _3])
    }
    public var Passport_Identity_EditDriversLicense: String { return self._s[3003]! }
    public var Conversation_TapAndHoldToRecord: String { return self._s[3005]! }
    public func Notification_CallTimeFormat(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3006]!, self._r[3006]!, [_1, _2])
    }
    public var Channel_EditAdmin_PermissionInviteViaLink: String { return self._s[3008]! }
    public func Generic_OpenHiddenLinkAlert(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3010]!, self._r[3010]!, [_0])
    }
    public var DialogList_Unread: String { return self._s[3011]! }
    public func PUSH_CHAT_MESSAGE_GIF(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3012]!, self._r[3012]!, [_1, _2])
    }
    public var User_DeletedAccount: String { return self._s[3013]! }
    public func Watch_Time_ShortYesterdayAt(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3014]!, self._r[3014]!, [_0])
    }
    public var UserInfo_NotificationsDefault: String { return self._s[3015]! }
    public var SharedMedia_CategoryMedia: String { return self._s[3016]! }
    public var SocksProxySetup_ProxyStatusUnavailable: String { return self._s[3017]! }
    public var Channel_AdminLog_MessageRestrictedForever: String { return self._s[3018]! }
    public var Watch_ChatList_Compose: String { return self._s[3019]! }
    public var Notifications_MessageNotificationsExceptionsHelp: String { return self._s[3020]! }
    public var Watch_Microphone_Access: String { return self._s[3021]! }
    public var Group_Setup_HistoryHeader: String { return self._s[3022]! }
    public var Activity_UploadingPhoto: String { return self._s[3023]! }
    public var Conversation_Edit: String { return self._s[3025]! }
    public var Group_ErrorSendRestrictedMedia: String { return self._s[3026]! }
    public var Login_TermsOfServiceDecline: String { return self._s[3027]! }
    public var Message_PinnedContactMessage: String { return self._s[3028]! }
    public func Channel_AdminLog_MessageRestrictedNameUsername(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3029]!, self._r[3029]!, [_1, _2])
    }
    public func Login_PhoneBannedEmailBody(_ _1: String, _ _2: String, _ _3: String, _ _4: String, _ _5: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3030]!, self._r[3030]!, [_1, _2, _3, _4, _5])
    }
    public var TwoStepAuth_AdditionalPassword: String { return self._s[3032]! }
    public func PUSH_CHAT_DELETE_YOU(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3033]!, self._r[3033]!, [_1, _2])
    }
    public var Passport_Phone_EnterOtherNumber: String { return self._s[3034]! }
    public var Message_PinnedPhotoMessage: String { return self._s[3035]! }
    public var Passport_FieldPhone: String { return self._s[3036]! }
    public var TwoStepAuth_RecoveryEmailAddDescription: String { return self._s[3037]! }
    public var InfoPlist_NSCameraUsageDescription: String { return self._s[3039]! }
    public var Conversation_Call: String { return self._s[3040]! }
    public var Common_TakePhoto: String { return self._s[3042]! }
    public var Channel_NotificationLoading: String { return self._s[3043]! }
    public func Notification_Exceptions_Sound(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3044]!, self._r[3044]!, [_0])
    }
    public func PUSH_CHANNEL_MESSAGE_VIDEO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3045]!, self._r[3045]!, [_1])
    }
    public var Permissions_SiriTitle_v0: String { return self._s[3046]! }
    public func Login_ResetAccountProtected_Text(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3047]!, self._r[3047]!, [_0])
    }
    public var Channel_MessagePhotoRemoved: String { return self._s[3048]! }
    public var Common_edit: String { return self._s[3049]! }
    public var PrivacySettings_AuthSessions: String { return self._s[3050]! }
    public var Month_ShortJune: String { return self._s[3051]! }
    public var PrivacyLastSeenSettings_AlwaysShareWith_Placeholder: String { return self._s[3052]! }
    public var Call_ReportSend: String { return self._s[3053]! }
    public var Watch_LastSeen_JustNow: String { return self._s[3054]! }
    public var Notifications_MessageNotifications: String { return self._s[3055]! }
    public var WallpaperSearch_ColorGreen: String { return self._s[3056]! }
    public var BroadcastListInfo_AddRecipient: String { return self._s[3058]! }
    public var Group_Status: String { return self._s[3059]! }
    public func AutoNightTheme_LocationHelp(_ _0: String, _ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3060]!, self._r[3060]!, [_0, _1])
    }
    public var ShareMenu_ShareTo: String { return self._s[3061]! }
    public var Conversation_Moderate_Ban: String { return self._s[3062]! }
    public func Conversation_DeleteMessagesFor(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3063]!, self._r[3063]!, [_0])
    }
    public var SharedMedia_ViewInChat: String { return self._s[3064]! }
    public var Map_LiveLocationFor8Hours: String { return self._s[3065]! }
    public func PUSH_PINNED_PHOTO(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3066]!, self._r[3066]!, [_1])
    }
    public func PUSH_PINNED_POLL(_ _1: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3067]!, self._r[3067]!, [_1])
    }
    public func Map_AccurateTo(_ _0: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3069]!, self._r[3069]!, [_0])
    }
    public var Map_OpenInHereMaps: String { return self._s[3070]! }
    public var Appearance_ReduceMotion: String { return self._s[3071]! }
    public func PUSH_MESSAGE_TEXT(_ _1: String, _ _2: String) -> (String, [(Int, NSRange)]) {
        return formatWithArgumentRanges(self._s[3072]!, self._r[3072]!, [_1, _2])
    }
    public var Channel_Setup_TypePublicHelp: String { return self._s[3073]! }
    public var Passport_Identity_EditInternalPassport: String { return self._s[3074]! }
    public var PhotoEditor_Skip: String { return self._s[3075]! }
    public func ServiceMessage_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[0 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Conversation_LiveLocationMembersCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[1 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_File(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[2 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func StickerPack_AddMaskCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[3 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ServiceMessage_GameScoreExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[4 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessagePoll_VotedCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[5 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedAuthorsOthers(_ selector: Int32, _ _0: String, _ _1: String) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[6 * 6 + Int(form.rawValue)]!, _0, _1)
    }
    public func PasscodeSettings_FailedAttempts(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[7 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_Generic(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[8 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHAT_MESSAGE_FWDS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[9 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func AttachmentMenu_SendPhoto(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[10 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedPhotos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[11 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Contacts_ImportersCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[12 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_DeleteItemsConfirmation(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[13 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Media_SharePhoto(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[14 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_Link(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[15 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Map_ETAHours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[16 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Years(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[17 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notification_GameScoreExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[18 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ServiceMessage_GameScoreSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[19 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedVideos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[20 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Call_ShortSeconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[21 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_Photo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[22 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func AttachmentMenu_SendItem(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[23 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[24 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func StickerPack_RemoveMaskCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[25 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedContacts(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[26 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Conversation_StatusSubscribers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[27 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHAT_MESSAGE_PHOTOS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[28 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func Notifications_ExceptionMuteExpires_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[29 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Passport_Scans(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[30 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func GroupInfo_ParticipantCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[31 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortDays(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[32 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Call_ShortMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[33 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Forward_ConfirmMultipleFiles(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[34 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHAT_MESSAGES(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[35 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func ForwardedGifs(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[36 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func UserCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[37 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Conversation_StatusMembers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[38 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Invitation_Members(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[39 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedFiles(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[40 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notifications_Exceptions(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[41 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_MESSAGE_ROUNDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[42 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Notification_GameScoreSelfExtended(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[43 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notification_GameScoreSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[44 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteExpires_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[45 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHAT_MESSAGE_VIDEOS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[46 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func StickerPack_RemoveStickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[47 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortSeconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[48 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func AttachmentMenu_SendGif(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[49 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_MESSAGE_VIDEOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[50 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func StickerPack_AddStickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[51 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func StickerPack_StickerCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[52 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHANNEL_MESSAGE_VIDEOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[53 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func QuickSend_Photos(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[54 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[55 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ServiceMessage_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[56 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func AttachmentMenu_SendVideo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[57 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[58 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Watch_UserInfo_Mute(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[59 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Watch_LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[60 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHANNEL_MESSAGES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[61 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func ForwardedLocations(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[62 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func CreatePoll_AddMoreOptions(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[63 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Months(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[64 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedVideoMessages(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[65 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Media_ShareItem(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[66 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func SharedMedia_Video(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[67 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PrivacyLastSeenSettings_AddUsers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[68 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notifications_ExceptionMuteExpires_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[69 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_ShortHours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[70 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Conversation_StatusOnline(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[71 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Media_ShareVideo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[72 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func LiveLocation_MenuChatsCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[73 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHAT_MESSAGE_ROUNDS(_ selector: Int32, _ _2: String, _ _1: String, _ _3: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[74 * 6 + Int(form.rawValue)]!, _2, _1, _3)
    }
    public func MessageTimer_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[75 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteExpires_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[76 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHANNEL_MESSAGE_ROUNDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[77 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Call_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[78 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedMessages(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[79 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Watch_LastSeen_HoursAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[80 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ChatList_DeleteConfirmation(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[81 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedStickers(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[82 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_MESSAGES(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[83 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MessageTimer_ShortWeeks(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[84 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteFor_Hours(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[85 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func InviteText_ContactsCountText(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[86 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Wallpaper_DeleteConfirmation(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[87 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_MESSAGE_FWDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[88 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func MessageTimer_Seconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[89 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[90 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHANNEL_MESSAGE_PHOTOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[91 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func DialogList_LiveLocationChatsCount(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[92 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func LiveLocationUpdated_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[93 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteExpires_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[94 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_MESSAGE_PHOTOS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[95 * 6 + Int(form.rawValue)]!, _1, _2)
    }
    public func Notifications_ExceptionMuteExpires_Minutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[96 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Map_ETAMinutes(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[97 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedAudios(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[98 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Call_Seconds(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[99 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func LastSeen_MinutesAgo(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[100 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func Notification_GameScoreSelfSimple(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[101 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func ForwardedPolls(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[102 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MessageTimer_Weeks(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[103 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func MuteFor_Days(_ value: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, value)
        return String(format: self._ps[104 * 6 + Int(form.rawValue)]!, "\(value)")
    }
    public func PUSH_CHANNEL_MESSAGE_FWDS(_ selector: Int32, _ _1: String, _ _2: Int32) -> String {
        let form = presentationStringsPluralizationForm(self.lc, selector)
        return String(format: self._ps[105 * 6 + Int(form.rawValue)]!, _1, _2)
    }
        
    init(primaryComponent: PresentationStringsComponent, secondaryComponent: PresentationStringsComponent?) {
        self.primaryComponent = primaryComponent
        self.secondaryComponent = secondaryComponent
        
        self.baseLanguageCode = secondaryComponent?.languageCode ?? primaryComponent.languageCode
        
        let languageCode = primaryComponent.pluralizationRulesCode ?? primaryComponent.languageCode
        var rawCode = languageCode as NSString
        var range = rawCode.range(of: "_")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        range = rawCode.range(of: "-")
        if range.location != NSNotFound {
            rawCode = rawCode.substring(to: range.location) as NSString
        }
        rawCode = rawCode.lowercased as NSString
        var lc: UInt32 = 0
        for i in 0 ..< rawCode.length {
            lc = (lc << 8) + UInt32(rawCode.character(at: i))
        }
        self.lc = lc

        var _s: [Int: String] = [:]
        var _r: [Int: [(Int, NSRange)]] = [:]
        
        let loadedKeyMapping = keyMapping
        
        let sIdList: [Int] = loadedKeyMapping.0
        let sKeyList: [String] = loadedKeyMapping.1
        let sArgIdList: [Int] = loadedKeyMapping.2
        for i in 0 ..< sIdList.count {
            _s[sIdList[i]] = getValue(primaryComponent, secondaryComponent, sKeyList[i])
        }
        for i in 0 ..< sArgIdList.count {
            _r[sArgIdList[i]] = extractArgumentRanges(_s[sArgIdList[i]]!)
        }
        self._s = _s
        self._r = _r

        var _ps: [Int: String] = [:]
        let pIdList: [Int] = loadedKeyMapping.3
        let pKeyList: [String] = loadedKeyMapping.4
        for i in 0 ..< pIdList.count {
            for form in 0 ..< 6 {
                _ps[pIdList[i] * 6 + form] = getValueWithForm(primaryComponent, secondaryComponent, pKeyList[i], PluralizationForm(rawValue: Int32(form))!)
            }
        }
        self._ps = _ps
    }
}

