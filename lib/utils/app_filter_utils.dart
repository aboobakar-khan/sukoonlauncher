import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

/// 🎯 Smart 3-Layer App Filtering (Industry Best Practice)
///
/// LAYER 1: Launcher Intent Filter (Plugin handles this)
/// - Only apps with ACTION_MAIN + CATEGORY_LAUNCHER
/// - Removes 70-80% of system junk automatically
///
/// LAYER 2: System vs User Classification
/// - User apps (non-system) → ALWAYS SHOW
/// - System apps → Apply strict filtering
///
/// LAYER 3: Minimal Junk Blocklist
/// - Small safe blocklist for known junk patterns
/// - Whitelist essential system apps
///
/// Result: ✅ Clean on first launch, ✅ Zero setup, ✅ Smart defaults
class AppFilterUtils {
  AppFilterUtils._();

  /// 🔒 Essential system apps users actually need (whitelisted)
  ///
  /// Brand-adaptive whitelist covering all major Android manufacturers:
  /// Google, Samsung, Xiaomi, OPPO, Vivo, OnePlus, Realme, ASUS
  ///
  /// ⚠️ Not every phone has all these installed.
  /// Whitelist means: "If present, allow it." Not required to exist.
  static const Set<String> allowedSystemApps = {
    // ═══════════════════════════════════════════════════════════
    // 📞 PHONE / DIALER
    // ═══════════════════════════════════════════════════════════
    'com.android.dialer',
    'com.google.android.dialer',
    'com.samsung.android.dialer',
    'com.miui.dialer',
    'com.oppo.dialer',
    'com.vivo.dialer',
    'com.oneplus.dialer',
    'com.realme.dialer',
    'com.asus.dialer',

    // ═══════════════════════════════════════════════════════════
    // 💬 MESSAGING / SMS
    // ═══════════════════════════════════════════════════════════
    'com.android.mms',
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
    'com.miui.mms',
    'com.oppo.messaging',
    'com.vivo.messaging',
    'com.oneplus.messaging',
    'com.whatsapp',
    'com.whatsapp.w4b',

    // ═══════════════════════════════════════════════════════════
    // 👥 CONTACTS
    // ═══════════════════════════════════════════════════════════
    'com.android.contacts',
    'com.google.android.contacts',
    'com.samsung.android.contacts',
    'com.miui.contacts',
    'com.oppo.contacts',
    'com.vivo.contacts',
    'com.oneplus.contacts',
    'com.coloros.dialer', // ColorOS Dialer
    'com.coloros.contacts', // ColorOS Contacts
    // ===== Huawei =====
    'com.huawei.contacts', // Huawei Contacts
    'com.huawei.dialer', // Huawei Dialer
    // ===== Asus =====
    'com.asus.contacts', // Asus Contacts
    // ===== Motorola =====
    'com.motorola.dialer', // Motorola Dialer
    'com.motorola.contacts', // Motorola Contacts
    // ═══════════════════════════════════════════════════════════
    // 📷 CAMERA
    // ═══════════════════════════════════════════════════════════
    'com.android.camera',
    'com.android.camera2',
    'com.google.android.GoogleCamera',
    'com.google.android.GoogleCameraGo',
    'com.sec.android.app.camera',
    'com.samsung.android.camera',
    'com.miui.camera',
    'com.oppo.camera',
    'com.coloros.camera',
    'com.coloros.camera2',
    'com.vivo.camera',
    'com.oneplus.camera',
    'com.realme.camera',
    'com.motorola.camera3',
    'com.motorola.camera2',
    'com.huawei.camera',
    'com.asus.camera',
    'com.sonyericsson.android.camera',
    'org.codeaurora.snapcam',
    'com.hmd.camera',
    'com.lava.camera',
    'com.lava.camera2',
    'com.transsion.camera',
    'com.mediatek.camera',
    'com.lenovo.camera',
    'com.nothing.camera',
    'com.tcl.camera',
    'com.zte.camera',
    'com.oneplus.camera.service', // OnePlus Camera Service
    'com.oneplus.camera.provider', // OnePlus Camera Provider
    'com.oplus.camera', // OPPO/OnePlus unified camera
    'com.agc.toolkit', // AGC Toolkit (shows as "Camera" on some OnePlus devices)

    // ═══════════════════════════════════════════════════════════
    // 🖼️ GALLERY / PHOTOS
    // ═══════════════════════════════════════════════════════════
    'com.android.gallery3d',
    'com.google.android.apps.photos',
    'com.miui.gallery',
    'com.samsung.android.gallery',
    'com.sec.android.gallery3d',
    'com.coloros.gallery3d',
    'com.vivo.gallery',

    // ═══════════════════════════════════════════════════════════
    // ⚙️ SETTINGS
    // ═══════════════════════════════════════════════════════════
    'com.android.settings',
    'com.google.android.settings',
    'com.samsung.android.settings',

    // ═══════════════════════════════════════════════════════════
    // ⏰ CLOCK / ALARM
    // ═══════════════════════════════════════════════════════════
    'com.android.deskclock',
    'com.google.android.deskclock',
    'com.sec.android.app.clockpackage',
    'com.miui.clock',
    'com.coloros.clock',
    'com.vivo.clock',
    'com.oneplus.clock',
    'com.realme.clock',

    // ═══════════════════════════════════════════════════════════
    // 📅 CALENDAR
    // ═══════════════════════════════════════════════════════════
    'com.android.calendar',
    'com.google.android.calendar',
    'com.samsung.android.calendar',
    'com.miui.calendar',
    'com.coloros.calendar',
    'com.vivo.calendar',
    'com.oneplus.calendar',
    'com.realme.calendar',
    'com.xiaomi.calendar',

    // ═══════════════════════════════════════════════════════════
    // 🧮 CALCULATOR
    // ═══════════════════════════════════════════════════════════
    'com.android.calculator2',
    'com.google.android.calculator',
    'com.sec.android.app.popupcalculator',
    'com.miui.calculator',
    'com.coloros.calculator',
    'com.vivo.calculator',
    'com.oneplus.calculator',
    'com.realme.calculator',

    // ═══════════════════════════════════════════════════════════
    // 📁 FILE MANAGER
    // ═══════════════════════════════════════════════════════════
    'com.android.documentsui',
    'com.google.android.documentsui',
    'com.google.android.apps.nbu.files',
    'com.sec.android.app.myfiles',
    'com.miui.Fileexplorer',
    'com.coloros.filemanager',
    'com.vivo.filemanager',
    'com.oneplus.filemanager',
    'com.mi.android.globleFileexplorer',
    'com.miui.fm',

    // ═══════════════════════════════════════════════════════════
    // 🌐 BROWSER
    // ═══════════════════════════════════════════════════════════
    'com.android.chrome',
    'com.sec.android.app.sbrowser',
    'com.mi.globalbrowser',
    'org.mozilla.firefox',
    'com.opera.browser',
    'com.brave.browser',

    // ═══════════════════════════════════════════════════════════
    // 🗺️ MAPS / NAVIGATION
    // ═══════════════════════════════════════════════════════════
    'com.google.android.apps.maps',
    'com.waze',

    // ═══════════════════════════════════════════════════════════
    // 🎵 MUSIC PLAYER
    // ═══════════════════════════════════════════════════════════
    'com.google.android.apps.youtube.music',
    'com.spotify.music',
    'com.apple.android.music',
    'com.samsung.android.app.music',
    'com.miui.player',
    'com.oppo.music',
    'com.vivo.music',
    'com.oneplus.music',
    'com.realme.music',
    'com.asus.music',

    // ═══════════════════════════════════════════════════════════
    // 📝 NOTES
    // ═══════════════════════════════════════════════════════════
    'com.google.android.keep',
    'com.samsung.android.app.notes',
    'com.miui.notes',
    'com.coloros.note',
    'com.vivo.notes',
    'com.oneplus.notes',
    'com.realme.notes',
    'com.asus.supernote',

    // ═══════════════════════════════════════════════════════════
    // 📦 APP STORE
    // ═══════════════════════════════════════════════════════════
    'com.android.vending',

    // ═══════════════════════════════════════════════════════════
    // 💳 PAYMENT
    // ═══════════════════════════════════════════════════════════
    'com.google.android.apps.walletnfchost', // Google Pay
    'com.google.android.apps.nbu.paisa.android', // Google Pay India
    'com.google.android.apps.nbu.paisa.user', // Google Pay India User
    'com.google.android.apps.pay', // Google Pay
    'com.samsung.android.spay', // Samsung Pay
    // ═══════════════════════════════════════════════════════════
    // 🤖 ASSISTANT
    // ═══════════════════════════════════════════════════════════
    'com.google.android.apps.googleassistant',
    'com.google.android.apps.bard', // Google Bard (older name)
    'com.google.android.apps.gemini', // Google Gemini AI Assistant

    // ═══════════════════════════════════════════════════════════
    // 📧 GOOGLE CORE APPS
    // ═══════════════════════════════════════════════════════════
    'com.google.android.gm', // Gmail
    'com.google.android.youtube',
    'com.google.android.googlequicksearchbox', // Search
    'com.google.android.apps.docs', // Drive
    // ═══════════════════════════════════════════════════════════
    // 📱 OTHER USER APPS
    // ═══════════════════════════════════════════════════════════
    'com.nis.app',
    'com.openai.chatgpt',
    // weather apps
    'com.samsung.android.weather', // Samsung Weather
    'com.miui.weather2', // Xiaomi Weather
    'com.huawei.weather', // Huawei Weather
    'com.oppo.weather', // Oppo Weather
    'com.vivo.weather', // Vivo Weather
    // 🇮🇳 Popular UPI Apps
    "com.phonepe.app", // PhonePe
    "net.one97.paytm", // Paytm
    "com.mobikwik_new", // MobiKwik
    "in.org.npci.upiapp", // BHIM UPI
    "in.amazon.mShop.android.shopping", // Amazon (Amazon Pay inside app)
    // 🌍 International / OEM Wallets
    "com.paypal.android.p2pmobile", // PayPal
    "com.venmo", // Venmo
    "com.squareup.cash", // Cash App
    // 🏦 SBI
    "com.sbi.upi", // SBI Pay
    "com.sbi.lotusintouch", // YONO SBI
    // 🏦 HDFC
    "com.snapwork.hdfc", // PayZapp
    "com.hdfcbank.mobilebanking", // HDFC Mobile Banking
    // 🏦 ICICI
    "com.csam.icici.bank.imobile", // iMobile Pay
    // 🏦 Axis Bank
    "com.axis.mobile", // Axis Mobile
    // 🏦 Kotak Bank
    "com.msf.kbank.mobile", // Kotak Mobile Banking
    // 🏦 Bank of Baroda
    "com.bankofbaroda.mconnect", // BOI m-Connect (Baroda)
    // 🏦 Punjab National Bank
    "com.pnb.ibanking", // PNB ONE
    // 🏦 Canara Bank
    "com.canarabank.mobility", // Canara ai1
    // 🏦 Union Bank
    "com.unionbank.ecommerce", // Union Bank App
    // 🏦 IDBI Bank
    "com.idbibank.mobilebanking", // IDBI Go Mobile+
    // 🏦 IndusInd Bank
    "com.indusind.indusmobile", // IndusMobile
    // 🏦 Yes Bank
    "com.atom.ybl", // YES PAY
    // 🏦 Federal Bank
    "com.federalbank.lotza", // FedMobile
    // 🏦 Bank of India
    "com.boi.mconnect", // BOI M-Connect
    // 🏦 Central Bank of India
    "com.infrasofttech.centralbank", // Cent Mobile
    // 🏦 UCO Bank
    "com.uco.mbanking", // UCO M-Banking
    // 🏦 Indian Bank
    "com.indianbank.indpay", // IndPAY
    // 🏦 Indian Overseas Bank
    "com.iob.android.mconnect", // IOB mConnect
    // 🏦 RBL Bank
    "com.rblbank.rblmycard", // RBL MyCard / UPI
    // 🏦 IDFC First Bank
    "com.idfcfirstbank.optimus", // IDFC FIRST Mobile Banking
    // 🌐 Google
    "com.google.android.apps.subscriptions.red", //Google one
    "com.google.android.apps.restore", // Google One Backup
    "com.google.android.gms", // Google Play Services (sync)
    "com.google.android.apps.cloudprint", // Google Cloud Print (legacy)
    // ☁️ Microsoft
    "com.microsoft.skydrive", // OneDrive
    "com.microsoft.office.outlook", // Outlook cloud sync
    "com.microsoft.office.officehubrow", // Office Hub
    // 📦 Dropbox / Mega / Box
    "com.dropbox.android", // Dropbox
    "mega.privacy.android.app", // MEGA Cloud
    "com.box.android", // Box Cloud
    // 🍏 Apple (rare on Android but exists)

    // 📱 Samsung
    "com.samsung.android.scloud", // Samsung Cloud
    "com.samsung.android.oneconnect", // SmartThings Cloud
    // 📱 Xiaomi / Redmi / POCO
    "com.miui.cloudservice", // Mi Cloud
    "com.miui.cloudbackup", // Mi Backup
    // 📱 Oppo / Realme
    "com.coloros.backuprestore", // Oppo Cloud Backup
    "com.heytap.cloud", // HeyTap Cloud
    "com.oppo.gallery3d", // Oppo Gallery Cloud
    // 📱 Vivo / iQOO
    "com.vivo.cloud", // Vivo Cloud
    "com.vivo.backup", // Vivo Backup
    // 📱 Huawei
    "com.huawei.hidisk", // Huawei Cloud Drive
    "com.huawei.hicloud", // Huawei Cloud
    "com.huawei.photos", // Huawei Photos Cloud
    // 📱 OnePlus
    "com.oneplus.cloud", // OnePlus Cloud
    "com.oneplus.backuprestore", // OnePlus Switch / Backup
    // 🔐 Secure Storage / Backup
    "com.google.android.apps.tachyon", // Google Duo backup

    'com.android.server.telecom', // Call routing service
    'com.android.incallui', // Call screen UI
    // 📱 Xiaomi / Redmi / POCO
    "com.miui.personalassistant", // App Vault
    "com.miui.home", // MIUI Launcher
    "com.miui.securitycenter", // Security App
    "com.miui.cleanmaster", // Cleaner
    "com.miui.powerkeeper", // Battery Saver
    // 📱 Samsung
    "com.samsung.android.app.spage", // Samsung Free / App Vault
    "com.sec.android.app.launcher", // One UI Launcher
    "com.samsung.android.lool", // Device Care
    // 📱 Oppo / Realme
    "com.coloros.assistantscreen", // Smart Assistant
    "com.coloros.smartsidebar", // Smart Sidebar
    "com.coloros.securitypermission", // Security Center
    "com.heytap.browser", // HeyTap Services
    // 📱 Vivo / iQOO
    "com.vivo.assistant", // Vivo Smart Assistant
    "com.vivo.easyshare", // EasyShare
    "com.iqoo.secure", // iQOO Security
    // 📱 Huawei
    "com.huawei.intelligent", // Huawei Assistant
    "com.huawei.systemmanager", // Phone Manager
    "com.huawei.himovie.overseas", // Huawei Services
    // 📱 OnePlus
    "com.oneplus.intelligentspace", // Shelf / Smart Space
    "com.oneplus.security", // OnePlus Security
    "com.oneplus.switch", // OnePlus Switch
    // 📱 Samsung
    "com.sec.android.app.samsungapps", // Galaxy Store
    // 📱 Xiaomi / Redmi / POCO
    "com.xiaomi.mipicks", // Mi Store / GetApps
    // 📱 Oppo / Realme
    "com.heytap.market", // App Market
    // 📱 Vivo / iQOO
    "com.bbk.appstore", // Vivo App Store
    // 📱 Huawei
    "com.huawei.appmarket", // Huawei AppGallery
    // 📱 OnePlus (uses Oppo store sometimes)
    "com.oppo.market", // Oppo App Market
    // 📱 Amazon Devices
    "com.amazon.venezia", // Amazon Appstore

    'com.mi.android.globalFileexplorer', // MIUI File Manager
    'com.mi.android.globalmiinusscreen', //miui app vault
    // 🌐 Google
    "com.google.android.apps.fitness", // Google Fit compass sensor access
    "com.google.android.apps.gmm", // (legacy maps)
    // 📱 Samsung
    "com.sec.android.app.compass", // Samsung Compass
    // 📱 Xiaomi / Redmi / POCO
    "com.miui.compass", // Mi Compass
    // 📱 Oppo / Realme
    "com.coloros.compass", // Oppo Compass
    "com.realme.compass", // Realme Compass
    // 📱 Vivo / iQOO
    "com.vivo.compass", // Vivo Compass
    // 📱 Huawei
    "com.huawei.compass", // Huawei Compass
    // 📦 Popular Third-Party Compass Apps
    "com.gamma.compass", // Smart Compass
    "net.androgames.compass", // Digital Compass
    "com.pixelprose.compass", // Accurate Compass
    "com.compass.direction", // Compass Direction
    "com.kwt.compass", // Compass Pro
    // 🌐 Google
    "com.google.android.gms.nearby.connection", // Nearby Services
    // 📱 Xiaomi / Redmi / POCO
    "com.xiaomi.midrop", // ShareMe (Mi Drop)
    "com.miui.mishare.connectivity", // Mi Share Service
    // 📱 Samsung
    "com.samsung.android.app.sharelive", // Quick Share
    "com.samsung.android.aware.service", // Nearby Share Service
    // 📱 Oppo / Realme
    "com.coloros.oshare", // OShare
    "com.heytap.nearby", // Nearby Share (HeyTap)
    // 📱 Vivo / iQOO
    "com.vivo.share", // Vivo Share
    // 📱 Huawei
    "com.huawei.android.instantshare", // Huawei Share
    "com.huawei.hisuite", // HiSuite Transfer
    // 📱 OnePlus
    "com.oneplus.transferservice", // OnePlus Clone Phone
    "com.oneplus.brickmode", // OnePlus Switch
    // 📦 Popular Third-Party Apps
    "com.lenovo.anyshare.gps", // SHAREit
    "com.xender", // Xender
    "com.jio.jiotransfer", // JioSwitch
    "com.smile.gifmaker", // Zapya
    "com.sendanywhere.android", // Send Anywhere
    // 🎤 Google
    "com.google.android.apps.recorder", // Google Recorder
    "com.google.android.apps.soundrecorder", // Google Sound Recorder
    // 📱 Samsung
    "com.sec.android.app.voicenote", // Samsung Voice Recorder
    "com.samsung.android.screenrecorder", // Samsung Screen Recorder
    // 📱 Xiaomi / Redmi / POCO
    "com.miui.voicerecorder", // Mi Voice Recorder
    "com.miui.screenrecorder", // Mi Screen Recorder
    'com.android.soundrecorder', // Default Android Sound Recorder
    'com.android.screenrecorder', // Default Android Screen Recorder
    // 📱 Oppo / Realme
    "com.coloros.soundrecorder", // Oppo Voice Recorder
    "com.coloros.screenrecorder", // Oppo Screen Recorder
    "com.realme.soundrecorder", // Realme Recorder
    "com.realme.screenrecorder", // Realme Screen Recorder
    // 📱 Vivo / iQOO
    "com.vivo.soundrecorder", // Vivo Recorder
    "com.vivo.screenrecorder", // Vivo Screen Recorder
    "com.iqoo.screenrecorder", // iQOO Screen Recorder
    // 📱 Huawei
    "com.huawei.soundrecorder", // Huawei Recorder
    "com.huawei.screenrecorder", // Huawei Screen Recorder
    // 📱 OnePlus
    "com.oneplus.soundrecorder", // OnePlus Recorder
    "com.oneplus.screenrecorder", // OnePlus Screen Recorder
    // 📦 Popular Third-Party Recorders
    "com.coffeebeanventures.easyvoicerecorder", // Easy Voice Recorder
    "com.media.bestrecorder.audiorecorder", // Smart Voice Recorder
    "com.llamalab.automate", // Automate Recorder
    "com.kimcy929.screenrecorder", // Screen Recorder (Kimcy)
    "com.hecorat.screenrecorder.free", // AZ Screen Recorder
    "com.mobzapp.screenrecorder", // Mobizen Screen Recorder
    // 🧘 Wellbeing / Digital Balance Apps
    // 🌐 Google
    "com.google.android.apps.wellbeing", // Digital Wellbeing
    "com.google.android.apps.kids.familylink", // Family Link (Parental Control)
    "com.google.android.apps.kids.familylinkhelper", // Family Link Helper
    // 📱 Samsung
    "com.samsung.android.wellbeing", // Samsung Digital Wellbeing
    "com.samsung.android.kidsinstaller", // Samsung Kids Mode
    "com.samsung.android.app.timenotification", // Screen Time Manager
    // 📱 Xiaomi / Redmi / POCO
    "com.miui.greenguard", // Digital Wellbeing (MIUI)
    "com.miui.kidsmode", // Kids Mode
    "com.miui.analytics", // Usage analytics
    // 📱 Oppo / Realme
    "com.coloros.digitalwellbeing", // Oppo Digital Wellbeing
    "com.realme.digitalwellbeing", // Realme Wellbeing
    "com.coloros.kidspace", // Kids Space
    // 📱 Vivo / iQOO
    "com.vivo.digitalwellbeing", // Vivo Wellbeing
    "com.iqoo.digitalwellbeing", // iQOO Wellbeing
    "com.vivo.kidsmode", // Kids Mode
    // 📱 Huawei
    "com.huawei.wellbeing", // Huawei Digital Balance
    "com.huawei.parentcontrol", // Parental Control
    // 📱 OnePlus
    "com.oneplus.digitalwellbeing", // OnePlus Wellbeing
    "com.oneplus.focusmode", // Zen / Focus Mode
    // 📦 Third-party Wellbeing Apps
    "com.stayfocused", // Stay Focused
    "com.forestapp", // Forest Focus
    "com.actiondash.android", // ActionDash
    "com.digitaldetox.android", // Digital Detox
    "com.offtime.android", // OFFTIME
    // 📷 QR Scanner Apps
    // 🌐 Google
    "com.google.android.apps.photos.scanner", // PhotoScan by Google
    "com.google.android.apps.walletnfcrel", // Google Wallet (QR Scanner)
    "com.google.zxing.client.android", // ZXing QR Scanner
    // 📱 Samsung
    "com.samsung.android.scanassistant", // Samsung Scan Assistant
    "com.sec.android.app.samsungscan", // Samsung Scanner
    // 📱 Xiaomi / Redmi / POCO
    "com.xiaomi.scanner", // Mi Scanner
    "com.miui.qrscanner", // MIUI QR Scanner
    // 📱 Oppo / Realme
    "com.coloros.scanner", // Oppo Scanner
    "com.realme.scanner", // Realme Scanner
    // 📱 Vivo / iQOO
    "com.vivo.scanner", // Vivo Scanner
    "com.iqoo.scanner", // iQOO Scanner
    // 📱 Huawei
    "com.huawei.scanner", // Huawei Scanner
    "com.huawei.hitouch", // HiTouch Scanner
    // 📱 OnePlus
    "com.oneplus.scanner", // OnePlus Scanner
    // 📦 Popular Third-Party Scanner Apps
    "com.adobe.scan.android", // Adobe Scan
    "com.microsoft.office.lens", // Microsoft Lens
    "com.camscanner", // CamScanner
    "com.documentscanner.pdfscanner", // Simple Scan
    "com.easy.scan", // Easy Scanner
    "com.smart.scan", // Smart Scan
    "com.scanbot.sdk.demo", // Scanbot
    // 🌐 Google
    "com.google.android.apps.wallpaper", // Google Wallpapers
    "com.google.android.wallpaper.pixel", // Pixel Wallpapers
    "com.google.android.apps.nexuslauncher", // Pixel Launcher (themes)
    "com.google.android.apps.customization.pixel", // Pixel Customization
    // 📱 Samsung
    "com.samsung.android.themestore", // Galaxy Themes
    "com.samsung.android.wallpaper.res", // Samsung Wallpapers
    // 📱 Xiaomi / Redmi / POCO
    "com.android.thememanager", // MIUI Themes

    "com.miui.miwallpaper", // Mi Wallpapers
    // 📱 Oppo / Realme
    "com.heytap.themestore", // Theme Store
    "com.coloros.wallpapers", // Oppo Wallpapers
    "com.realme.wallpapers", // Realme Wallpapers
    // 📱 Vivo / iQOO
    "com.bbk.theme", // Vivo Theme Store
    "com.vivo.wallpaper", // Vivo Wallpapers
    // 📱 Huawei
    "com.huawei.android.thememanager", // Huawei Themes
    "com.huawei.android.thememanager.overseas", // Huawei Themes Global
    // 📱 OnePlus
    "com.oneplus.wallpaper", // OnePlus Wallpapers
    "com.oneplus.launcher", // OnePlus Launcher
    // 📦 Popular Third-Party Theme Apps
    "com.zhiliaoapp.musically", // TikTok Themes (Live wallpapers)
    "com.kapp.ifunny", // Live wallpaper engine
    "com.wallpaper.hd", // HD Wallpapers
    "com.zeroteam.zerolauncher", // Zero Launcher Themes
    "com.teslacoilsw.launcher", // Nova Launcher (themes)
    "com.actionlauncher.playstore", // Action Launcher
    // 🤖 Android System
    "com.android.providers.downloads", // Android Download Manager (core)
    "com.android.providers.downloads.ui", // Downloads UI
    // 📱 Samsung
    "com.samsung.android.downloadmanager", // Samsung Download Manager
    // 📱 Xiaomi / Redmi / POCO
    "com.miui.downloadprovider", // MIUI Download Manager
    "com.miui.browser", // Mi Browser Downloads
    // 📱 Vivo / iQOO
    "com.vivo.browser", // Vivo Browser Downloads
    // 📱 Huawei
    "com.huawei.filemanager", // Huawei Files
    "com.huawei.browser", // Huawei Browser
    // 📦 Popular Third-Party Downloaders
    "com.dv.adm", // Advanced Download Manager
    "idm.internet.download.manager", // IDM Downloader
    "com.videoder", // Videoder
    "com.utorrent.client", // uTorrent Downloader
    "com.flashdownload", // Loader Droid
  };

  /// Apps without launcher intent that we can still launch using native intents
  /// These apps exist but don't appear in the system launcher list
  static const Set<String> hiddenLaunchableApps = {
    'com.google.android.apps.nbu.paisa.user', // Google Pay India
    'com.google.android.apps.nbu.paisa.android', // Google Pay India
    'com.google.android.apps.pay', // Google Pay
  };

  /// 🚫 Minimal junk patterns (only patterns ALWAYS junk across all devices)
  static const List<String> _junkPatterns = [
    '.updater',
    '.setup',
    '.feedback',
    '.partner',
    '.stub',
    '.test',
    '.overlay',
    'inputmethod', // Keyboard services (not the main app)
    'syncadapter',
  ];

  /// Check if package matches junk pattern
  static bool _isKnownJunk(String packageName) {
    final pkg = packageName.toLowerCase();
    return _junkPatterns.any((pattern) => pkg.contains(pattern));
  }

  /// 🧠 Core filtering logic - simplified for clean approach
  static bool _shouldIncludeApp(
    String packageName,
    String appName,
  ) {
    final pkg = packageName.toLowerCase();

    // ════════════════════════════════════════════════════
    // PRIORITY 1: Block This Launcher Itself
    // ════════════════════════════
    if (pkg == 'com.sukoon.launcher') return false;

    // ════════════════════════════════════════════════════
    // PRIORITY 2: Block Known Junk Patterns
    // ════════════════════════════════════════════════════
    if (_isKnownJunk(pkg)) return false;

    // ════════════════════════════════════════════════════
    // DEFAULT: Show Everything Else
    // ════════════════════════════════════════════════════
    // At this point, we already have:
    // ✓ User apps (from excludeSystemApps = true)
    // ✓ Whitelisted system apps (manually added)
    // → SHOW IT
    return true;
  }

  /// Get all installed apps for debugging (shows everything)
  static Future<List<AppInfo>> getAllAppsForDebug() async {
    return await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      withIcon: false,
    );
  }

  /// Check if an app is in the whitelist
  static bool isInWhitelist(String packageName) {
    return allowedSystemApps.contains(packageName.toLowerCase());
  }

  /// Get filtered apps - optimized async version
  static Future<List<AppInfo>> getFilteredAppsAlternative() async {
    // ════════════════════════════════════════════════════════════
    // INDUSTRY BEST PRACTICE: Start clean, add essentials
    // ════════════════════════════════════════════════════════════

    // Step 1: Get ONLY user-installed apps (clean by default)
    // excludeSystemApps = true → only user apps
    final userApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: false,
    );

    // Step 2: Get ALL apps (to extract whitelisted system apps)
    final allApps = await InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      withIcon: false,
    );

    // Step 3: Extract ONLY whitelisted essential system apps
    final essentialSystemApps = allApps.where((app) {
      return allowedSystemApps.contains(app.packageName.toLowerCase());
    }).toList();

    // Step 4: Combine user apps + essential system apps
    final combinedApps = <String, AppInfo>{};

    // Add all user apps
    for (final app in userApps) {
      combinedApps[app.packageName] = app;
    }

    // Add whitelisted system apps
    for (final app in essentialSystemApps) {
      combinedApps[app.packageName] = app;
    }

    // Step 4b: Add hidden-but-launchable apps (e.g., Google Pay without launcher intent)
    for (final app in allApps) {
      if (hiddenLaunchableApps.contains(app.packageName.toLowerCase()) &&
          !combinedApps.containsKey(app.packageName)) {
        combinedApps[app.packageName] = app;
      }
    }

    // Step 5: Apply final filtering
    final filtered = combinedApps.values.where((app) {
      return _shouldIncludeApp(
        app.packageName,
        app.name,
      );
    }).toList();

    // Sort alphabetically
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return filtered;
  }

  /// Synchronous version for backwards compatibility
  @Deprecated('Use getFilteredAppsAlternative() instead')
  static List<AppInfo> filterUsefulApps(
    List<AppInfo> allApps,
  ) {
    final filtered = allApps
        .where(
          (app) => _shouldIncludeApp(
            app.packageName,
            app.name,
          ),
        )
        .toList();

    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }
}
