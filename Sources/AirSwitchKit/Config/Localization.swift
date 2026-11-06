import Foundation

public enum AppLanguage: String, CaseIterable, Sendable {
    case en = "en"
    case fr = "fr"
    case de = "de"
    case es = "es"
    case it = "it"
    case pt = "pt"
    case nl = "nl"
    case pl = "pl"
    case ru = "ru"
    case tr = "tr"
    case ar = "ar"
    case hi = "hi"
    case ja = "ja"
    case ko = "ko"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"

    public var nativeName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .nl: return "Nederlands"
        case .pl: return "Polski"
        case .ru: return "Русский"
        case .tr: return "Türkçe"
        case .ar: return "العربية"
        case .hi: return "हिन्दी"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }

    public static func resolve(identifier: String) -> AppLanguage? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let exact = AppLanguage(rawValue: trimmed) {
            return exact
        }

        let normalized = trimmed.replacingOccurrences(of: "_", with: "-").lowercased()
        for lang in AppLanguage.allCases where lang.rawValue.lowercased() == normalized {
            return lang
        }

        if normalized.hasPrefix("zh") {
            if normalized.contains("hant") || normalized.contains("-tw") || normalized.contains("-hk") || normalized.contains("-mo") {
                return .zhHant
            }
            return .zhHans
        }

        let primarySubtag = normalized.split(separator: "-").first.map(String.init) ?? normalized
        return AppLanguage.allCases.first { $0.rawValue.lowercased() == primarySubtag }
    }

    public static func resolveSystemLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for tag in preferredLanguages {
            if let match = resolve(identifier: tag) {
                return match
            }
        }
        return .en
    }
}

public enum L10n {
    public static var currentLanguage: AppLanguage {
        if let overrideCode = Preferences.shared.appLanguage,
           let overrideLang = AppLanguage.resolve(identifier: overrideCode) {
            return overrideLang
        }
        return AppLanguage.resolveSystemLanguage()
    }

    private static var strings: Strings {
        catalog[currentLanguage] ?? catalog[.en]!
    }

    // MARK: - General & Status
    public static var connected: String { strings.connected }
    public static var disconnected: String { strings.disconnected }
    public static var paired: String { strings.paired }
    public static var connect: String { strings.connect }
    public static var disconnect: String { strings.disconnect }
    public static var connecting: String { strings.connecting }
    public static var disconnecting: String { strings.disconnecting }
    public static var connectionFailed: String { strings.connectionFailed }
    public static var disconnectionFailed: String { strings.disconnectionFailed }
    public static var headphones: String { strings.headphones }
    public static var selectedAsPrimaryDevice: String { strings.selectedAsPrimaryDevice }
    public static var autoConnectedOnWake: String { strings.autoConnectedOnWake }

    // MARK: - Battery
    public static var batteryLeftShort: String { strings.batteryLeftShort }
    public static var batteryRightShort: String { strings.batteryRightShort }
    public static var batteryCase: String { strings.batteryCase }
    public static func lowBattery(_ percent: Int) -> String {
        strings.lowBatteryFormat.replacingOccurrences(of: "%d", with: "\(percent)")
    }

    // MARK: - Menu Bar
    public static var noTargetDeviceHeader: String { strings.noTargetDeviceHeader }
    public static var targetAudioDevice: String { strings.targetAudioDevice }
    public static var noPairedAudioDevicesFound: String { strings.noPairedAudioDevicesFound }
    public static func globalShortcutMenu(_ combo: String) -> String {
        strings.globalShortcutMenuFormat.replacingOccurrences(of: "%@", with: combo)
    }
    public static var autoConnectOnWake: String { strings.autoConnectOnWake }
    public static var autoDisconnectOnSleep: String { strings.autoDisconnectOnSleep }
    public static var showFloatingBatteryHUD: String { strings.showFloatingBatteryHUD }
    public static var hudAnimations: String { strings.hudAnimations }
    public static var launchAtLogin: String { strings.launchAtLogin }
    public static var languageMenu: String { strings.languageMenu }
    public static func systemDefaultLanguage(_ resolvedName: String) -> String {
        "\(strings.systemDefault) (\(resolvedName))"
    }
    public static func installUpdate(_ tag: String) -> String {
        strings.installUpdateFormat.replacingOccurrences(of: "%@", with: tag)
    }
    public static var checkForUpdates: String { strings.checkForUpdates }
    public static var upToDate: String { strings.upToDate }
    public static var updateCheckFailed: String { strings.updateCheckFailed }
    public static var updateFailed: String { strings.updateFailed }
    public static var quitAirSwitch: String { strings.quitAirSwitch }

    // MARK: - Shortcut Recorder
    public static var globalShortcutTitle: String { strings.globalShortcutTitle }
    public static var globalToggleShortcutHeader: String { strings.globalToggleShortcutHeader }
    public static var shortcutPrompt: String { strings.shortcutPrompt }
    public static var shortcutModifierWarning: String { strings.shortcutModifierWarning }
    public static func shortcutReserved(_ combo: String) -> String {
        strings.shortcutReservedFormat.replacingOccurrences(of: "%@", with: combo)
    }
    public static var shortcutUpdated: String { strings.shortcutUpdated }
    public static func resetToDefault(_ combo: String) -> String {
        strings.resetToDefaultFormat.replacingOccurrences(of: "%@", with: combo)
    }
    public static var cancel: String { strings.cancel }

    // MARK: - Onboarding
    public static var welcomeToAirSwitch: String { strings.welcomeToAirSwitch }
    public static var choosePrimaryHeadphones: String { strings.choosePrimaryHeadphones }
    public static var refreshDevices: String { strings.refreshDevices }
    public static var refreshPairedDevices: String { strings.refreshPairedDevices }
    public static var emptyPairedDevicesMessage: String { strings.emptyPairedDevicesMessage }
    public static var continueButton: String { strings.continueButton }
    public static var continueWithoutDevice: String { strings.continueWithoutDevice }
    public static var toggleConnectionAnytime: String { strings.toggleConnectionAnytime }
    public static var selectedAccessibility: String { strings.selectedAccessibility }
    public static var notSelectedAccessibility: String { strings.notSelectedAccessibility }

    // MARK: - Semantic HUD Classification
    public static func isTransitioningSubtitle(_ subtitle: String) -> Bool {
        let lower = subtitle.lowercased()
        if lower.contains("connecting") || lower.contains("disconnecting") {
            return true
        }
        if allTransitioningSubtitles.contains(lower) {
            return true
        }
        return allInstallUpdatePrefixes.contains { lower.hasPrefix($0) }
    }

    public static func isFailureSubtitle(_ subtitle: String) -> Bool {
        let lower = subtitle.lowercased()
        if lower.contains("failed") {
            return true
        }
        return allFailureSubtitles.contains(lower)
    }

    public static func isDefaultConnectedSubtitle(_ subtitle: String) -> Bool {
        let lower = subtitle.lowercased()
        if lower.isEmpty { return true }
        return allDefaultConnectedSubtitles.contains(lower)
    }

    public static func isDefaultDisconnectedSubtitle(_ subtitle: String) -> Bool {
        let lower = subtitle.lowercased()
        if lower.isEmpty { return true }
        return allDefaultDisconnectedSubtitles.contains(lower)
    }

    private static let allTransitioningSubtitles: Set<String> = {
        var set = Set<String>()
        for entry in catalog.values {
            set.insert(entry.connecting.lowercased())
            set.insert(entry.disconnecting.lowercased())
            set.insert(entry.checkForUpdates.lowercased())
        }
        return set
    }()

    private static let allInstallUpdatePrefixes: [String] = {
        catalog.values.compactMap { entry in
            let prefix = entry.installUpdateFormat
                .components(separatedBy: "(%@)")
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return (prefix?.isEmpty == false) ? prefix : nil
        }
    }()

    private static let allFailureSubtitles: Set<String> = {
        var set = Set<String>()
        for entry in catalog.values {
            set.insert(entry.connectionFailed.lowercased())
            set.insert(entry.disconnectionFailed.lowercased())
            set.insert(entry.updateCheckFailed.lowercased())
            set.insert(entry.updateFailed.lowercased())
        }
        return set
    }()

    private static let allDefaultConnectedSubtitles: Set<String> = {
        var set = Set<String>()
        for entry in catalog.values {
            set.insert(entry.connected.lowercased())
            set.insert(entry.autoConnectedOnWake.lowercased())
        }
        return set
    }()

    private static let allDefaultDisconnectedSubtitles: Set<String> = {
        var set = Set<String>()
        for entry in catalog.values {
            set.insert(entry.disconnected.lowercased())
        }
        return set
    }()

    private struct Strings: Sendable {
        let connected: String
        let disconnected: String
        let paired: String
        let connect: String
        let disconnect: String
        let connecting: String
        let disconnecting: String
        let connectionFailed: String
        let disconnectionFailed: String
        let headphones: String
        let selectedAsPrimaryDevice: String
        let autoConnectedOnWake: String
        let batteryLeftShort: String
        let batteryRightShort: String
        let batteryCase: String
        let lowBatteryFormat: String
        let noTargetDeviceHeader: String
        let targetAudioDevice: String
        let noPairedAudioDevicesFound: String
        let globalShortcutMenuFormat: String
        let autoConnectOnWake: String
        let autoDisconnectOnSleep: String
        let showFloatingBatteryHUD: String
        let hudAnimations: String
        let launchAtLogin: String
        let languageMenu: String
        let systemDefault: String
        let installUpdateFormat: String
        let checkForUpdates: String
        let upToDate: String
        let updateCheckFailed: String
        let updateFailed: String
        let quitAirSwitch: String
        let globalShortcutTitle: String
        let globalToggleShortcutHeader: String
        let shortcutPrompt: String
        let shortcutModifierWarning: String
        let shortcutReservedFormat: String
        let shortcutUpdated: String
        let resetToDefaultFormat: String
        let cancel: String
        let welcomeToAirSwitch: String
        let choosePrimaryHeadphones: String
        let refreshDevices: String
        let refreshPairedDevices: String
        let emptyPairedDevicesMessage: String
        let continueButton: String
        let continueWithoutDevice: String
        let toggleConnectionAnytime: String
        let selectedAccessibility: String
        let notSelectedAccessibility: String
    }

    private static let catalog: [AppLanguage: Strings] = [
        .en: Strings(
            connected: "Connected",
            disconnected: "Disconnected",
            paired: "Paired",
            connect: "Connect",
            disconnect: "Disconnect",
            connecting: "Connecting...",
            disconnecting: "Disconnecting...",
            connectionFailed: "Connection Failed",
            disconnectionFailed: "Disconnection Failed",
            headphones: "Headphones",
            selectedAsPrimaryDevice: "Selected as primary device",
            autoConnectedOnWake: "Auto-connected on wake",
            batteryLeftShort: "L",
            batteryRightShort: "R",
            batteryCase: "Case",
            lowBatteryFormat: "Low Battery (%d%)",
            noTargetDeviceHeader: "AirSwitch — No target device",
            targetAudioDevice: "Target Audio Device",
            noPairedAudioDevicesFound: "No paired audio devices found",
            globalShortcutMenuFormat: "Global Shortcut (%@)…",
            autoConnectOnWake: "Auto-connect on Wake (Lid Open)",
            autoDisconnectOnSleep: "Auto-disconnect on Sleep (Lid Close)",
            showFloatingBatteryHUD: "Show Floating Battery HUD",
            hudAnimations: "HUD Animations",
            launchAtLogin: "Launch at Login",
            languageMenu: "Language",
            systemDefault: "System Default",
            installUpdateFormat: "Install Update (%@)…",
            checkForUpdates: "Check for Updates…",
            upToDate: "Up to date",
            updateCheckFailed: "Update Check Failed",
            updateFailed: "Update Failed",
            quitAirSwitch: "Quit AirSwitch",
            globalShortcutTitle: "Global Shortcut",
            globalToggleShortcutHeader: "Global Toggle Shortcut",
            shortcutPrompt: "Press a new key combination (Esc to cancel)",
            shortcutModifierWarning: "Include Control (⌃), Option (⌥), or Command (⌘)",
            shortcutReservedFormat: "%@ is reserved by macOS — try another",
            shortcutUpdated: "Shortcut Updated",
            resetToDefaultFormat: "Reset to Default (%@)",
            cancel: "Cancel",
            welcomeToAirSwitch: "Welcome to AirSwitch",
            choosePrimaryHeadphones: "Choose your primary headphones",
            refreshDevices: "Refresh devices",
            refreshPairedDevices: "Refresh paired devices",
            emptyPairedDevicesMessage: "No paired Bluetooth headphones found.\nPair your headphones in Bluetooth Settings, then click ↻.",
            continueButton: "Continue",
            continueWithoutDevice: "Continue Without Device",
            toggleConnectionAnytime: "Toggle connection anytime",
            selectedAccessibility: "Selected",
            notSelectedAccessibility: "Not selected"
        ),
        .fr: Strings(
            connected: "Connecté",
            disconnected: "Déconnecté",
            paired: "Jumelé",
            connect: "Connecter",
            disconnect: "Déconnecter",
            connecting: "Connexion…",
            disconnecting: "Déconnexion…",
            connectionFailed: "Échec de la connexion",
            disconnectionFailed: "Échec de la déconnexion",
            headphones: "Casque",
            selectedAsPrimaryDevice: "Défini comme appareil principal",
            autoConnectedOnWake: "Reconnecté à la sortie de veille",
            batteryLeftShort: "G",
            batteryRightShort: "D",
            batteryCase: "Boîtier",
            lowBatteryFormat: "Batterie faible (%d%)",
            noTargetDeviceHeader: "AirSwitch — Aucun appareil cible",
            targetAudioDevice: "Appareil audio cible",
            noPairedAudioDevicesFound: "Aucun appareil audio jumelé trouvé",
            globalShortcutMenuFormat: "Raccourci global (%@)…",
            autoConnectOnWake: "Connexion auto à la sortie de veille",
            autoDisconnectOnSleep: "Déconnexion auto à la mise en veille",
            showFloatingBatteryHUD: "Afficher le HUD de batterie",
            hudAnimations: "Animations du HUD",
            launchAtLogin: "Lancer à l’ouverture de session",
            languageMenu: "Langue",
            systemDefault: "Par défaut (macOS)",
            installUpdateFormat: "Installer la mise à jour (%@)…",
            checkForUpdates: "Rechercher des mises à jour…",
            upToDate: "À jour",
            updateCheckFailed: "Échec de la vérification",
            updateFailed: "Échec de la mise à jour",
            quitAirSwitch: "Quitter AirSwitch",
            globalShortcutTitle: "Raccourci global",
            globalToggleShortcutHeader: "Raccourci global d’activation",
            shortcutPrompt: "Appuyez sur une combinaison (Échap pour annuler)",
            shortcutModifierWarning: "Incluez Contrôle (⌃), Option (⌥) ou Commande (⌘)",
            shortcutReservedFormat: "%@ est réservé par macOS — essayez un autre",
            shortcutUpdated: "Raccourci mis à jour",
            resetToDefaultFormat: "Par défaut (%@)",
            cancel: "Annuler",
            welcomeToAirSwitch: "Bienvenue dans AirSwitch",
            choosePrimaryHeadphones: "Choisissez votre casque ou vos écouteurs principaux",
            refreshDevices: "Actualiser les appareils",
            refreshPairedDevices: "Actualiser les appareils jumelés",
            emptyPairedDevicesMessage: "Aucun casque Bluetooth jumelé trouvé.\nJumelez vos écouteurs dans les réglages Bluetooth, puis cliquez sur ↻.",
            continueButton: "Continuer",
            continueWithoutDevice: "Continuer sans appareil",
            toggleConnectionAnytime: "Basculez la connexion à tout moment",
            selectedAccessibility: "Sélectionné",
            notSelectedAccessibility: "Non sélectionné"
        ),
        .de: Strings(
            connected: "Verbunden",
            disconnected: "Getrennt",
            paired: "Gekoppelt",
            connect: "Verbinden",
            disconnect: "Trennen",
            connecting: "Verbinden…",
            disconnecting: "Trennen…",
            connectionFailed: "Verbindung fehlgeschlagen",
            disconnectionFailed: "Trennen fehlgeschlagen",
            headphones: "Kopfhörer",
            selectedAsPrimaryDevice: "Als primäres Gerät ausgewählt",
            autoConnectedOnWake: "Beim Aufwachen verbunden",
            batteryLeftShort: "L",
            batteryRightShort: "R",
            batteryCase: "Case",
            lowBatteryFormat: "Batterie schwach (%d%)",
            noTargetDeviceHeader: "AirSwitch — Kein Zielgerät",
            targetAudioDevice: "Ziel-Audiogerät",
            noPairedAudioDevicesFound: "Keine gekoppelten Audiogeräte gefunden",
            globalShortcutMenuFormat: "Globaler Kurzbefehl (%@)…",
            autoConnectOnWake: "Beim Aufwachen automatisch verbinden",
            autoDisconnectOnSleep: "Beim Ruhezustand automatisch trennen",
            showFloatingBatteryHUD: "Schwebendes Batterie-HUD anzeigen",
            hudAnimations: "HUD-Animationen",
            launchAtLogin: "Bei der Anmeldung starten",
            languageMenu: "Sprache",
            systemDefault: "Systemstandard",
            installUpdateFormat: "Update installieren (%@)…",
            checkForUpdates: "Nach Updates suchen…",
            upToDate: "Auf dem neuesten Stand",
            updateCheckFailed: "Updateprüfung fehlgeschlagen",
            updateFailed: "Update fehlgeschlagen",
            quitAirSwitch: "AirSwitch beenden",
            globalShortcutTitle: "Globaler Kurzbefehl",
            globalToggleShortcutHeader: "Globaler Umschalt-Kurzbefehl",
            shortcutPrompt: "Neue Tastenkombination drücken (Esc zum Abbrechen)",
            shortcutModifierWarning: "Control (⌃), Option (⌥) oder Command (⌘) verwenden",
            shortcutReservedFormat: "%@ ist von macOS reserviert — wähle eine andere",
            shortcutUpdated: "Kurzbefehl aktualisiert",
            resetToDefaultFormat: "Auf Standard zurücksetzen (%@)",
            cancel: "Abbrechen",
            welcomeToAirSwitch: "Willkommen bei AirSwitch",
            choosePrimaryHeadphones: "Wähle deine primären Kopfhörer",
            refreshDevices: "Geräte aktualisieren",
            refreshPairedDevices: "Gekoppelte Geräte aktualisieren",
            emptyPairedDevicesMessage: "Keine gekoppelten Bluetooth-Kopfhörer gefunden.\nKopple deine Kopfhörer in den Bluetooth-Einstellungen und klicke auf ↻.",
            continueButton: "Weiter",
            continueWithoutDevice: "Ohne Gerät fortfahren",
            toggleConnectionAnytime: "Verbindung jederzeit umschalten",
            selectedAccessibility: "Ausgewählt",
            notSelectedAccessibility: "Nicht ausgewählt"
        ),
        .es: Strings(
            connected: "Conectado",
            disconnected: "Desconectado",
            paired: "Enlazado",
            connect: "Conectar",
            disconnect: "Desconectar",
            connecting: "Conectando…",
            disconnecting: "Desconectando…",
            connectionFailed: "Error de conexión",
            disconnectionFailed: "Error al desconectar",
            headphones: "Auriculares",
            selectedAsPrimaryDevice: "Seleccionado como dispositivo principal",
            autoConnectedOnWake: "Conectado al activar el Mac",
            batteryLeftShort: "I",
            batteryRightShort: "D",
            batteryCase: "Estuche",
            lowBatteryFormat: "Batería baja (%d%)",
            noTargetDeviceHeader: "AirSwitch — Sin dispositivo",
            targetAudioDevice: "Dispositivo de audio",
            noPairedAudioDevicesFound: "No se encontraron dispositivos de audio enlazados",
            globalShortcutMenuFormat: "Atajo global (%@)…",
            autoConnectOnWake: "Conectar al despertar (abrir tapa)",
            autoDisconnectOnSleep: "Desconectar en reposo (cerrar tapa)",
            showFloatingBatteryHUD: "Mostrar HUD flotante de batería",
            hudAnimations: "Animaciones del HUD",
            launchAtLogin: "Abrir al iniciar sesión",
            languageMenu: "Idioma",
            systemDefault: "Predeterminado del sistema",
            installUpdateFormat: "Instalar actualización (%@)…",
            checkForUpdates: "Buscar actualizaciones…",
            upToDate: "Actualizado",
            updateCheckFailed: "Error al buscar actualizaciones",
            updateFailed: "Error al actualizar",
            quitAirSwitch: "Salir de AirSwitch",
            globalShortcutTitle: "Atajo global",
            globalToggleShortcutHeader: "Atajo global de conexión",
            shortcutPrompt: "Pulsa una combinación de teclas (Esc para cancelar)",
            shortcutModifierWarning: "Incluye Control (⌃), Opción (⌥) o Comando (⌘)",
            shortcutReservedFormat: "%@ está reservado por macOS — prueba otro",
            shortcutUpdated: "Atajo actualizado",
            resetToDefaultFormat: "Restaurar (%@)",
            cancel: "Cancelar",
            welcomeToAirSwitch: "Bienvenido a AirSwitch",
            choosePrimaryHeadphones: "Elige tus auriculares principales",
            refreshDevices: "Actualizar dispositivos",
            refreshPairedDevices: "Actualizar dispositivos enlazados",
            emptyPairedDevicesMessage: "No se encontraron auriculares Bluetooth enlazados.\nEnlázalos en Ajustes de Bluetooth y haz clic en ↻.",
            continueButton: "Continuar",
            continueWithoutDevice: "Continuar sin dispositivo",
            toggleConnectionAnytime: "Alterna la conexión en cualquier momento",
            selectedAccessibility: "Seleccionado",
            notSelectedAccessibility: "No seleccionado"
        ),
        .it: Strings(
            connected: "Connesso",
            disconnected: "Disconnesso",
            paired: "Abbinato",
            connect: "Connetti",
            disconnect: "Disconnetti",
            connecting: "Connessione…",
            disconnecting: "Disconnessione…",
            connectionFailed: "Connessione non riuscita",
            disconnectionFailed: "Disconnessione non riuscita",
            headphones: "Cuffie",
            selectedAsPrimaryDevice: "Selezionato come dispositivo principale",
            autoConnectedOnWake: "Connesso al risveglio",
            batteryLeftShort: "S",
            batteryRightShort: "D",
            batteryCase: "Custodia",
            lowBatteryFormat: "Batteria scarica (%d%)",
            noTargetDeviceHeader: "AirSwitch — Nessun dispositivo",
            targetAudioDevice: "Dispositivo audio principale",
            noPairedAudioDevicesFound: "Nessun dispositivo audio abbinato",
            globalShortcutMenuFormat: "Abbreviazione globale (%@)…",
            autoConnectOnWake: "Connetti al risveglio (apertura coperchio)",
            autoDisconnectOnSleep: "Disconnetti in stop (chiusura coperchio)",
            showFloatingBatteryHUD: "Mostra HUD batteria fluttuante",
            hudAnimations: "Animazioni HUD",
            launchAtLogin: "Apri al login",
            languageMenu: "Lingua",
            systemDefault: "Predefinita di sistema",
            installUpdateFormat: "Installa aggiornamento (%@)…",
            checkForUpdates: "Controlla aggiornamenti…",
            upToDate: "Aggiornato",
            updateCheckFailed: "Controllo aggiornamenti non riuscito",
            updateFailed: "Aggiornamento non riuscito",
            quitAirSwitch: "Esci da AirSwitch",
            globalShortcutTitle: "Abbreviazione globale",
            globalToggleShortcutHeader: "Abbreviazione globale di attivazione",
            shortcutPrompt: "Premi una nuova combinazione (Esc per annullare)",
            shortcutModifierWarning: "Includi Control (⌃), Opzione (⌥) o Comando (⌘)",
            shortcutReservedFormat: "%@ è riservato da macOS — provane un altro",
            shortcutUpdated: "Abbreviazione aggiornata",
            resetToDefaultFormat: "Ripristina (%@)",
            cancel: "Annulla",
            welcomeToAirSwitch: "Benvenuto in AirSwitch",
            choosePrimaryHeadphones: "Scegli le tue cuffie principali",
            refreshDevices: "Aggiorna dispositivi",
            refreshPairedDevices: "Aggiorna dispositivi abbinati",
            emptyPairedDevicesMessage: "Nessuna cuffia Bluetooth abbinata trovata.\nAbbina le cuffie nelle impostazioni Bluetooth, poi fai clic su ↻.",
            continueButton: "Continua",
            continueWithoutDevice: "Continua senza dispositivo",
            toggleConnectionAnytime: "Attiva o disattiva la connessione in qualsiasi momento",
            selectedAccessibility: "Selezionato",
            notSelectedAccessibility: "Non selezionato"
        ),
        .pt: Strings(
            connected: "Conectado",
            disconnected: "Desconectado",
            paired: "Emparelhado",
            connect: "Conectar",
            disconnect: "Desconectar",
            connecting: "Conectando…",
            disconnecting: "Desconectando…",
            connectionFailed: "Falha na conexão",
            disconnectionFailed: "Falha ao desconectar",
            headphones: "Fones de ouvido",
            selectedAsPrimaryDevice: "Selecionado como dispositivo principal",
            autoConnectedOnWake: "Conectado ao despertar",
            batteryLeftShort: "E",
            batteryRightShort: "D",
            batteryCase: "Estojo",
            lowBatteryFormat: "Bateria fraca (%d%)",
            noTargetDeviceHeader: "AirSwitch — Nenhum dispositivo",
            targetAudioDevice: "Dispositivo de áudio alvo",
            noPairedAudioDevicesFound: "Nenhum dispositivo de áudio emparelhado",
            globalShortcutMenuFormat: "Atalho global (%@)…",
            autoConnectOnWake: "Conectar ao despertar (abrir tampa)",
            autoDisconnectOnSleep: "Desconectar ao repousar (fechar tampa)",
            showFloatingBatteryHUD: "Mostrar HUD flutuante de bateria",
            hudAnimations: "Animações do HUD",
            launchAtLogin: "Iniciar no login",
            languageMenu: "Idioma",
            systemDefault: "Padrão do sistema",
            installUpdateFormat: "Instalar atualização (%@)…",
            checkForUpdates: "Verificar atualizações…",
            upToDate: "Atualizado",
            updateCheckFailed: "Falha ao verificar atualizações",
            updateFailed: "Falha na atualização",
            quitAirSwitch: "Encerrar AirSwitch",
            globalShortcutTitle: "Atalho global",
            globalToggleShortcutHeader: "Atalho global de alternância",
            shortcutPrompt: "Pressione uma combinação de teclas (Esc para cancelar)",
            shortcutModifierWarning: "Inclua Control (⌃), Option (⌥) ou Command (⌘)",
            shortcutReservedFormat: "%@ é reservado pelo macOS — tente outro",
            shortcutUpdated: "Atalho atualizado",
            resetToDefaultFormat: "Restaurar padrão (%@)",
            cancel: "Cancelar",
            welcomeToAirSwitch: "Bem-vindo ao AirSwitch",
            choosePrimaryHeadphones: "Escolha seus fones de ouvido principais",
            refreshDevices: "Atualizar dispositivos",
            refreshPairedDevices: "Atualizar dispositivos emparelhados",
            emptyPairedDevicesMessage: "Nenhum fone Bluetooth emparelhado encontrado.\nEmparelhe nos Ajustes de Bluetooth e clique em ↻.",
            continueButton: "Continuar",
            continueWithoutDevice: "Continuar sem dispositivo",
            toggleConnectionAnytime: "Alterne a conexão a qualquer momento",
            selectedAccessibility: "Selecionado",
            notSelectedAccessibility: "Não selecionado"
        ),
        .nl: Strings(
            connected: "Verbonden",
            disconnected: "Niet verbonden",
            paired: "Gekoppeld",
            connect: "Verbind",
            disconnect: "Verbreek verbinding",
            connecting: "Verbinden…",
            disconnecting: "Verbinding verbreken…",
            connectionFailed: "Verbinding mislukt",
            disconnectionFailed: "Verbreken mislukt",
            headphones: "Koptelefoon",
            selectedAsPrimaryDevice: "Geselecteerd als primair apparaat",
            autoConnectedOnWake: "Verbonden bij ontwaken",
            batteryLeftShort: "L",
            batteryRightShort: "R",
            batteryCase: "Case",
            lowBatteryFormat: "Batterij bijna leeg (%d%)",
            noTargetDeviceHeader: "AirSwitch — Geen doelapparaat",
            targetAudioDevice: "Doel-audioapparaat",
            noPairedAudioDevicesFound: "Geen gekoppelde audioapparaten gevonden",
            globalShortcutMenuFormat: "Globale sneltoets (%@)…",
            autoConnectOnWake: "Automatisch verbinden bij ontwaken",
            autoDisconnectOnSleep: "Automatisch verbreken bij sluimerstand",
            showFloatingBatteryHUD: "Zwevende batterij-HUD tonen",
            hudAnimations: "HUD-animaties",
            launchAtLogin: "Start bij inloggen",
            languageMenu: "Taal",
            systemDefault: "Systeemstandaard",
            installUpdateFormat: "Update installeren (%@)…",
            checkForUpdates: "Controleer op updates…",
            upToDate: "Up-to-date",
            updateCheckFailed: "Updatecontrole mislukt",
            updateFailed: "Update mislukt",
            quitAirSwitch: "Stop AirSwitch",
            globalShortcutTitle: "Globale sneltoets",
            globalToggleShortcutHeader: "Globale schakelsneltoets",
            shortcutPrompt: "Druk op een toetscombinatie (Esc om te annuleren)",
            shortcutModifierWarning: "Gebruik Control (⌃), Option (⌥) of Command (⌘)",
            shortcutReservedFormat: "%@ is gereserveerd door macOS — probeer een andere",
            shortcutUpdated: "Sneltoets bijgewerkt",
            resetToDefaultFormat: "Standaard (%@)",
            cancel: "Annuleer",
            welcomeToAirSwitch: "Welkom bij AirSwitch",
            choosePrimaryHeadphones: "Kies je primaire koptelefoon",
            refreshDevices: "Apparaten vernieuwen",
            refreshPairedDevices: "Gekoppelde apparaten vernieuwen",
            emptyPairedDevicesMessage: "Geen gekoppelde Bluetooth-koptelefoon gevonden.\nKoppel je koptelefoon in Bluetooth-instellingen en klik op ↻.",
            continueButton: "Ga door",
            continueWithoutDevice: "Ga door zonder apparaat",
            toggleConnectionAnytime: "Schakel verbinding op elk moment",
            selectedAccessibility: "Geselecteerd",
            notSelectedAccessibility: "Niet geselecteerd"
        ),
        .pl: Strings(
            connected: "Połączono",
            disconnected: "Rozłączono",
            paired: "Sparowano",
            connect: "Połącz",
            disconnect: "Rozłącz",
            connecting: "Łączenie…",
            disconnecting: "Rozłączanie…",
            connectionFailed: "Błąd połączenia",
            disconnectionFailed: "Błąd rozłączania",
            headphones: "Słuchawki",
            selectedAsPrimaryDevice: "Wybrano jako urządzenie główne",
            autoConnectedOnWake: "Połączono po wybudzeniu",
            batteryLeftShort: "L",
            batteryRightShort: "P",
            batteryCase: "Etui",
            lowBatteryFormat: "Słaba bateria (%d%)",
            noTargetDeviceHeader: "AirSwitch — Brak urządzenia",
            targetAudioDevice: "Docelowe urządzenie audio",
            noPairedAudioDevicesFound: "Brak sparowanych urządzeń audio",
            globalShortcutMenuFormat: "Skrót globalny (%@)…",
            autoConnectOnWake: "Automatycznie łącz po wybudzeniu",
            autoDisconnectOnSleep: "Automatycznie rozłącz przy uśpieniu",
            showFloatingBatteryHUD: "Pokaż pływający HUD baterii",
            hudAnimations: "Animacje HUD",
            launchAtLogin: "Uruchamiaj przy logowaniu",
            languageMenu: "Język",
            systemDefault: "Domyślny systemu",
            installUpdateFormat: "Zainstaluj aktualizację (%@)…",
            checkForUpdates: "Sprawdź uaktualnienia…",
            upToDate: "Aktualna wersja",
            updateCheckFailed: "Błąd sprawdzania aktualizacji",
            updateFailed: "Aktualizacja nie powiodła się",
            quitAirSwitch: "Zakończ AirSwitch",
            globalShortcutTitle: "Skrót globalny",
            globalToggleShortcutHeader: "Globalny skrót przełączania",
            shortcutPrompt: "Naciśnij nową kombinację klawiszy (Esc aby anulować)",
            shortcutModifierWarning: "Użyj klawisza Control (⌃), Option (⌥) lub Command (⌘)",
            shortcutReservedFormat: "%@ jest zarezerwowany przez macOS — wybierz inny",
            shortcutUpdated: "Zaktualizowano skrót",
            resetToDefaultFormat: "Przywróć domyślny (%@)",
            cancel: "Anuluj",
            welcomeToAirSwitch: "Witaj w AirSwitch",
            choosePrimaryHeadphones: "Wybierz główne słuchawki",
            refreshDevices: "Odśwież urządzenia",
            refreshPairedDevices: "Odśwież sparowane urządzenia",
            emptyPairedDevicesMessage: "Nie znaleziono sparowanych słuchawek Bluetooth.\nSparuj słuchawki w ustawieniach Bluetooth i kliknij ↻.",
            continueButton: "Dalej",
            continueWithoutDevice: "Kontynuuj bez urządzenia",
            toggleConnectionAnytime: "Przełączaj połączenie w dowolnej chwili",
            selectedAccessibility: "Wybrano",
            notSelectedAccessibility: "Nie wybrano"
        ),
        .ru: Strings(
            connected: "Подключено",
            disconnected: "Отключено",
            paired: "В паре",
            connect: "Подключить",
            disconnect: "Отключить",
            connecting: "Подключение…",
            disconnecting: "Отключение…",
            connectionFailed: "Ошибка подключения",
            disconnectionFailed: "Ошибка отключения",
            headphones: "Наушники",
            selectedAsPrimaryDevice: "Выбрано основным устройством",
            autoConnectedOnWake: "Подключено при пробуждении",
            batteryLeftShort: "Л",
            batteryRightShort: "П",
            batteryCase: "Футляр",
            lowBatteryFormat: "Низкий заряд (%d%)",
            noTargetDeviceHeader: "AirSwitch — Устройство не выбрано",
            targetAudioDevice: "Целевое аудиоустройство",
            noPairedAudioDevicesFound: "Сопряженные аудиоустройства не найдены",
            globalShortcutMenuFormat: "Глобальное сочетание (%@)…",
            autoConnectOnWake: "Автоподключение при пробуждении",
            autoDisconnectOnSleep: "Автоотключение в режиме сна",
            showFloatingBatteryHUD: "Показывать индикатор заряда (HUD)",
            hudAnimations: "Анимации HUD",
            launchAtLogin: "Запускать при входе",
            languageMenu: "Язык",
            systemDefault: "По умолчанию (macOS)",
            installUpdateFormat: "Установить обновление (%@)…",
            checkForUpdates: "Проверить обновления…",
            upToDate: "Установлена последняя версия",
            updateCheckFailed: "Ошибка проверки обновлений",
            updateFailed: "Ошибка обновления",
            quitAirSwitch: "Завершить AirSwitch",
            globalShortcutTitle: "Глобальное сочетание",
            globalToggleShortcutHeader: "Сочетание клавиш переключения",
            shortcutPrompt: "Нажмите комбинацию клавиш (Esc для отмены)",
            shortcutModifierWarning: "Добавьте Control (⌃), Option (⌥) или Command (⌘)",
            shortcutReservedFormat: "%@ занято macOS — выберите другое",
            shortcutUpdated: "Сочетание обновлено",
            resetToDefaultFormat: "По умолчанию (%@)",
            cancel: "Отмена",
            welcomeToAirSwitch: "Добро пожаловать в AirSwitch",
            choosePrimaryHeadphones: "Выберите основные наушники",
            refreshDevices: "Обновить устройства",
            refreshPairedDevices: "Обновить сопряженные устройства",
            emptyPairedDevicesMessage: "Сопряженные Bluetooth-наушники не найдены.\nПодключите их в настройках Bluetooth и нажмите ↻.",
            continueButton: "Продолжить",
            continueWithoutDevice: "Продолжить без устройства",
            toggleConnectionAnytime: "Переключайте соединение в любой момент",
            selectedAccessibility: "Выбрано",
            notSelectedAccessibility: "Не выбрано"
        ),
        .tr: Strings(
            connected: "Bağlı",
            disconnected: "Bağlı Değil",
            paired: "Eşleşmiş",
            connect: "Bağlan",
            disconnect: "Bağlantıyı Kes",
            connecting: "Bağlanıyor…",
            disconnecting: "Bağlantı kesiliyor…",
            connectionFailed: "Bağlantı Başarısız",
            disconnectionFailed: "Bağlantı Kesilemedi",
            headphones: "Kulaklık",
            selectedAsPrimaryDevice: "Birincil aygıt olarak seçildi",
            autoConnectedOnWake: "Uyanınca otomatik bağlandı",
            batteryLeftShort: "Sol",
            batteryRightShort: "Sağ",
            batteryCase: "Kutu",
            lowBatteryFormat: "Düşük Pil (%d%)",
            noTargetDeviceHeader: "AirSwitch — Hedef aygıt yok",
            targetAudioDevice: "Hedef Ses Aygıtı",
            noPairedAudioDevicesFound: "Eşleşmiş ses aygıtı bulunamadı",
            globalShortcutMenuFormat: "Genel Kısayol (%@)…",
            autoConnectOnWake: "Uyanınca Otomatik Bağlan (Kapak Açık)",
            autoDisconnectOnSleep: "Uykuda Otomatik Kes (Kapak Kapalı)",
            showFloatingBatteryHUD: "Yüzen Pil HUD’unu Göster",
            hudAnimations: "HUD Animasyonları",
            launchAtLogin: "Oturum Açıldığında Başlat",
            languageMenu: "Dil",
            systemDefault: "Sistem Varsayılanı",
            installUpdateFormat: "Güncellemeyi Yükle (%@)…",
            checkForUpdates: "Güncellemeleri Denetle…",
            upToDate: "Güncel",
            updateCheckFailed: "Güncelleme Denetimi Başarısız",
            updateFailed: "Güncelleme Başarısız",
            quitAirSwitch: "AirSwitch’ten Çık",
            globalShortcutTitle: "Genel Kısayol",
            globalToggleShortcutHeader: "Genel Geçiş Kısayolu",
            shortcutPrompt: "Yeni bir tuş kombinasyonuna basın (İptal için Esc)",
            shortcutModifierWarning: "Control (⌃), Option (⌥) veya Command (⌘) ekleyin",
            shortcutReservedFormat: "%@ macOS tarafından ayrılmış — başka deneyin",
            shortcutUpdated: "Kısayol Güncellendi",
            resetToDefaultFormat: "Varsayılana Sıfırla (%@)",
            cancel: "Vazgeç",
            welcomeToAirSwitch: "AirSwitch’e Hoş Geldiniz",
            choosePrimaryHeadphones: "Birincil kulaklığınızı seçin",
            refreshDevices: "Aygıtları yenile",
            refreshPairedDevices: "Eşleşmiş aygıtları yenile",
            emptyPairedDevicesMessage: "Eşleşmiş Bluetooth kulaklık bulunamadı.\nBluetooth Ayarlarında kulaklığınızı eşleştirip ↻ düğmesine tıklayın.",
            continueButton: "Devam",
            continueWithoutDevice: "Aygıt Olmadan Devam Et",
            toggleConnectionAnytime: "Bağlantıyı istediğiniz zaman değiştirin",
            selectedAccessibility: "Seçili",
            notSelectedAccessibility: "Seçili değil"
        ),
        .ar: Strings(
            connected: "متصل",
            disconnected: "غير متصل",
            paired: "مقترن",
            connect: "اتصال",
            disconnect: "قطع الاتصال",
            connecting: "جارٍ الاتصال…",
            disconnecting: "جارٍ قطع الاتصال…",
            connectionFailed: "فشل الاتصال",
            disconnectionFailed: "فشل قطع الاتصال",
            headphones: "سماعات الرأس",
            selectedAsPrimaryDevice: "تم التحديد كجهاز رئيسي",
            autoConnectedOnWake: "تم الاتصال تلقائيًا عند الاستيقاظ",
            batteryLeftShort: "يسار",
            batteryRightShort: "يمين",
            batteryCase: "العلبة",
            lowBatteryFormat: "البطارية منخفضة (%d%)",
            noTargetDeviceHeader: "AirSwitch — لا يوجد جهاز محدد",
            targetAudioDevice: "جهاز الصوت المستهدف",
            noPairedAudioDevicesFound: "لم يتم العثور على أجهزة صوت مقترنة",
            globalShortcutMenuFormat: "اختصار عام (%@)…",
            autoConnectOnWake: "اتصال تلقائي عند الاستيقاظ",
            autoDisconnectOnSleep: "قطع الاتصال تلقائيًا عند الإسبات",
            showFloatingBatteryHUD: "إظهار شاشة البطارية العائمة",
            hudAnimations: "تأثيرات الحركة",
            launchAtLogin: "البدء عند تسجيل الدخول",
            languageMenu: "اللغة",
            systemDefault: "افتراضي النظام",
            installUpdateFormat: "تثبيت التحديث (%@)…",
            checkForUpdates: "التحقق من التحديثات…",
            upToDate: "محدّث لأحدث إصدار",
            updateCheckFailed: "فشل التحقق من التحديثات",
            updateFailed: "فشل التحديث",
            quitAirSwitch: "إنهاء AirSwitch",
            globalShortcutTitle: "اختصار عام",
            globalToggleShortcutHeader: "اختصار التبديل العام",
            shortcutPrompt: "اضغط على مجموعة مفاتيح جديدة (Esc للإلغاء)",
            shortcutModifierWarning: "يجب تضمين Control (⌃) أو Option (⌥) أو Command (⌘)",
            shortcutReservedFormat: "%@ محجوز بواسطة macOS — جرّب اختصارًا آخر",
            shortcutUpdated: "تم تحديث الاختصار",
            resetToDefaultFormat: "إعادة للافتراضي (%@)",
            cancel: "إلغاء",
            welcomeToAirSwitch: "مرحبًا بك في AirSwitch",
            choosePrimaryHeadphones: "اختر سماعة الرأس الرئيسية",
            refreshDevices: "تحديث الأجهزة",
            refreshPairedDevices: "تحديث الأجهزة المقترنة",
            emptyPairedDevicesMessage: "لم يتم العثور على سماعات Bluetooth مقترنة.\nقم بإقران سماعتك في إعدادات Bluetooth ثم انقر على ↻.",
            continueButton: "متابعة",
            continueWithoutDevice: "المتابعة بدون جهاز",
            toggleConnectionAnytime: "بدّل الاتصال في أي وقت",
            selectedAccessibility: "محدد",
            notSelectedAccessibility: "غير محدد"
        ),
        .hi: Strings(
            connected: "कनेक्टेड",
            disconnected: "डिस्कनेक्टेड",
            paired: "पेयर्ड",
            connect: "कनेक्ट करें",
            disconnect: "डिस्कनेक्ट करें",
            connecting: "कनेक्ट हो रहा है…",
            disconnecting: "डिस्कनेक्ट हो रहा है…",
            connectionFailed: "कनेक्शन विफल",
            disconnectionFailed: "डिस्कनेक्ट विफल",
            headphones: "हेडफ़ोन",
            selectedAsPrimaryDevice: "प्राथमिक डिवाइस के रूप में चुना गया",
            autoConnectedOnWake: "वेक होने पर स्वतः कनेक्ट हुआ",
            batteryLeftShort: "L",
            batteryRightShort: "R",
            batteryCase: "केस",
            lowBatteryFormat: "कम बैटरी (%d%)",
            noTargetDeviceHeader: "AirSwitch — कोई डिवाइस चयनित नहीं",
            targetAudioDevice: "लक्षित ऑडियो डिवाइस",
            noPairedAudioDevicesFound: "कोई पेयर्ड ऑडियो डिवाइस नहीं मिला",
            globalShortcutMenuFormat: "ग्लोबल शॉर्टकट (%@)…",
            autoConnectOnWake: "वेक पर ऑटो-कनेक्ट (लिड खुलने पर)",
            autoDisconnectOnSleep: "स्लीप पर ऑटो-डिस्कनेक्ट (लिड बंद होने पर)",
            showFloatingBatteryHUD: "फ़्लोटिंग बैटरी HUD दिखाएँ",
            hudAnimations: "HUD एनिमेशन",
            launchAtLogin: "लॉगिन पर लॉन्च करें",
            languageMenu: "भाषा",
            systemDefault: "सिस्टम डिफ़ॉल्ट",
            installUpdateFormat: "अपडेट इंस्टॉल करें (%@)…",
            checkForUpdates: "अपडेट की जाँच करें…",
            upToDate: "अप टू डेट",
            updateCheckFailed: "अपडेट जाँच विफल",
            updateFailed: "अपडेट विफल",
            quitAirSwitch: "AirSwitch बंद करें",
            globalShortcutTitle: "ग्लोबल शॉर्टकट",
            globalToggleShortcutHeader: "ग्लोबल टॉगल शॉर्टकट",
            shortcutPrompt: "नया की-कॉम्बिनेशन दबाएँ (रद्द करने के लिए Esc)",
            shortcutModifierWarning: "Control (⌃), Option (⌥) या Command (⌘) शामिल करें",
            shortcutReservedFormat: "%@ macOS द्वारा आरक्षित है — दूसरा चुनें",
            shortcutUpdated: "शॉर्टकट अपडेट किया गया",
            resetToDefaultFormat: "डिफ़ॉल्ट पर रीसेट करें (%@)",
            cancel: "रद्द करें",
            welcomeToAirSwitch: "AirSwitch में आपका स्वागत है",
            choosePrimaryHeadphones: "अपना प्राथमिक हेडफ़ोन चुनें",
            refreshDevices: "डिवाइस रीफ़्रेश करें",
            refreshPairedDevices: "पेयर्ड डिवाइस रीफ़्रेश करें",
            emptyPairedDevicesMessage: "कोई पेयर्ड Bluetooth हेडफ़ोन नहीं मिला।\nBluetooth सेटिंग्स में हेडफ़ोन पेयर करें, फिर ↻ पर क्लिक करें।",
            continueButton: "जारी रखें",
            continueWithoutDevice: "बिना डिवाइस जारी रखें",
            toggleConnectionAnytime: "कभी भी कनेक्शन टॉगल करें",
            selectedAccessibility: "चयनित",
            notSelectedAccessibility: "अचयनित"
        ),
        .ja: Strings(
            connected: "接続済み",
            disconnected: "未接続",
            paired: "ペアリング済み",
            connect: "接続",
            disconnect: "接続解除",
            connecting: "接続中…",
            disconnecting: "切断中…",
            connectionFailed: "接続に失敗しました",
            disconnectionFailed: "切断に失敗しました",
            headphones: "ヘッドフォン",
            selectedAsPrimaryDevice: "メインデバイスに設定しました",
            autoConnectedOnWake: "スリープ解除時に自動接続しました",
            batteryLeftShort: "L",
            batteryRightShort: "R",
            batteryCase: "ケース",
            lowBatteryFormat: "バッテリー残量低下 (%d%)",
            noTargetDeviceHeader: "AirSwitch — デバイス未選択",
            targetAudioDevice: "対象オーディオデバイス",
            noPairedAudioDevicesFound: "ペアリング済みのオーディオデバイスがありません",
            globalShortcutMenuFormat: "グローバルショートカット (%@)…",
            autoConnectOnWake: "スリープ解除時に自動接続",
            autoDisconnectOnSleep: "スリープ時に自動切断",
            showFloatingBatteryHUD: "フローティングバッテリーHUDを表示",
            hudAnimations: "HUDアニメーション",
            launchAtLogin: "ログイン時に起動",
            languageMenu: "言語",
            systemDefault: "システム設定に従う",
            installUpdateFormat: "アップデートをインストール (%@)…",
            checkForUpdates: "アップデートを確認…",
            upToDate: "最新バージョンです",
            updateCheckFailed: "アップデートの確認に失敗",
            updateFailed: "アップデートに失敗",
            quitAirSwitch: "AirSwitchを終了",
            globalShortcutTitle: "グローバルショートカット",
            globalToggleShortcutHeader: "接続切り替えショートカット",
            shortcutPrompt: "新しいキーの組み合わせを押してください (Escでキャンセル)",
            shortcutModifierWarning: "Control (⌃)、Option (⌥)、Command (⌘) のいずれかを含めてください",
            shortcutReservedFormat: "%@ はmacOSで使用されています — 別のキーを試してください",
            shortcutUpdated: "ショートカットを更新しました",
            resetToDefaultFormat: "デフォルトに戻す (%@)",
            cancel: "キャンセル",
            welcomeToAirSwitch: "AirSwitchへようこそ",
            choosePrimaryHeadphones: "メインで使うヘッドフォンを選択してください",
            refreshDevices: "デバイスを更新",
            refreshPairedDevices: "ペアリング済みデバイスを更新",
            emptyPairedDevicesMessage: "ペアリング済みのBluetoothヘッドフォンが見つかりません。\nBluetooth設定でペアリングしてから ↻ をクリックしてください。",
            continueButton: "続ける",
            continueWithoutDevice: "選択せずに続ける",
            toggleConnectionAnytime: "いつでも接続を切り替えられます",
            selectedAccessibility: "選択済み",
            notSelectedAccessibility: "未選択"
        ),
        .ko: Strings(
            connected: "연결됨",
            disconnected: "연결 안 됨",
            paired: "페어링됨",
            connect: "연결",
            disconnect: "연결 해제",
            connecting: "연결 중…",
            disconnecting: "연결 해제 중…",
            connectionFailed: "연결 실패",
            disconnectionFailed: "연결 해제 실패",
            headphones: "헤드폰",
            selectedAsPrimaryDevice: "기본 기기로 선택됨",
            autoConnectedOnWake: "깨우기 시 자동 연결됨",
            batteryLeftShort: "L",
            batteryRightShort: "R",
            batteryCase: "케이스",
            lowBatteryFormat: "배터리 부족 (%d%)",
            noTargetDeviceHeader: "AirSwitch — 대상 기기 없음",
            targetAudioDevice: "대상 오디오 기기",
            noPairedAudioDevicesFound: "페어링된 오디오 기기 없음",
            globalShortcutMenuFormat: "전역 단축키 (%@)…",
            autoConnectOnWake: "깨우기 시 자동 연결 (덮개 열기)",
            autoDisconnectOnSleep: "잠자기 시 자동 연결 해제 (덮개 닫기)",
            showFloatingBatteryHUD: "플로팅 배터리 HUD 표시",
            hudAnimations: "HUD 애니메이션",
            launchAtLogin: "로그인 시 실행",
            languageMenu: "언어",
            systemDefault: "시스템 기본값",
            installUpdateFormat: "업데이트 설치 (%@)…",
            checkForUpdates: "업데이트 확인…",
            upToDate: "최신 버전입니다",
            updateCheckFailed: "업데이트 확인 실패",
            updateFailed: "업데이트 실패",
            quitAirSwitch: "AirSwitch 종료",
            globalShortcutTitle: "전역 단축키",
            globalToggleShortcutHeader: "전역 연결 전환 단축키",
            shortcutPrompt: "새로운 키 조합을 누르세요 (취소하려면 Esc)",
            shortcutModifierWarning: "Control(⌃), Option(⌥) 또는 Command(⌘)를 포함하세요",
            shortcutReservedFormat: "%@ 단축키는 macOS에서 예약되어 있습니다",
            shortcutUpdated: "단축키 업데이트됨",
            resetToDefaultFormat: "기본값으로 재설정 (%@)",
            cancel: "취소",
            welcomeToAirSwitch: "AirSwitch에 오신 것을 환영합니다",
            choosePrimaryHeadphones: "기본으로 사용할 헤드폰을 선택하세요",
            refreshDevices: "기기 새로고침",
            refreshPairedDevices: "페어링된 기기 새로고침",
            emptyPairedDevicesMessage: "페어링된 Bluetooth 헤드폰을 찾을 수 없습니다.\nBluetooth 설정에서 페어링한 후 ↻ 버튼을 클릭하세요.",
            continueButton: "계속",
            continueWithoutDevice: "기기 없이 계속",
            toggleConnectionAnytime: "언제든지 연결을 전환하세요",
            selectedAccessibility: "선택됨",
            notSelectedAccessibility: "선택 안 됨"
        ),
        .zhHans: Strings(
            connected: "已连接",
            disconnected: "未连接",
            paired: "已配对",
            connect: "连接",
            disconnect: "断开连接",
            connecting: "正在连接…",
            disconnecting: "正在断开…",
            connectionFailed: "连接失败",
            disconnectionFailed: "断开连接失败",
            headphones: "耳机",
            selectedAsPrimaryDevice: "已设为首选设备",
            autoConnectedOnWake: "唤醒时已自动连接",
            batteryLeftShort: "左",
            batteryRightShort: "右",
            batteryCase: "充电盒",
            lowBatteryFormat: "电量低 (%d%)",
            noTargetDeviceHeader: "AirSwitch — 未选择目标设备",
            targetAudioDevice: "目标音频设备",
            noPairedAudioDevicesFound: "未找到已配对的音频设备",
            globalShortcutMenuFormat: "全局快捷键 (%@)…",
            autoConnectOnWake: "唤醒时自动连接（开盖）",
            autoDisconnectOnSleep: "睡眠时自动断开（合盖）",
            showFloatingBatteryHUD: "显示悬浮电量 HUD",
            hudAnimations: "HUD 动画",
            launchAtLogin: "登录时启动",
            languageMenu: "语言",
            systemDefault: "跟随系统",
            installUpdateFormat: "安装更新 (%@)…",
            checkForUpdates: "检查更新…",
            upToDate: "已是最新版本",
            updateCheckFailed: "检查更新失败",
            updateFailed: "更新失败",
            quitAirSwitch: "退出 AirSwitch",
            globalShortcutTitle: "全局快捷键",
            globalToggleShortcutHeader: "全局切换快捷键",
            shortcutPrompt: "请按下新的快捷键组合（按 Esc 取消）",
            shortcutModifierWarning: "需包含 Control (⌃)、Option (⌥) 或 Command (⌘)",
            shortcutReservedFormat: "%@ 已被 macOS 占用，请尝试其他组合",
            shortcutUpdated: "快捷键已更新",
            resetToDefaultFormat: "恢复默认 (%@)",
            cancel: "取消",
            welcomeToAirSwitch: "欢迎使用 AirSwitch",
            choosePrimaryHeadphones: "选择你的主力耳机",
            refreshDevices: "刷新设备",
            refreshPairedDevices: "刷新已配对设备",
            emptyPairedDevicesMessage: "未找到已配对的蓝牙耳机。\n请在蓝牙设置中配对耳机，然后点击 ↻。",
            continueButton: "继续",
            continueWithoutDevice: "暂不选择并继续",
            toggleConnectionAnytime: "随时一键切换连接",
            selectedAccessibility: "已选中",
            notSelectedAccessibility: "未选中"
        ),
        .zhHant: Strings(
            connected: "已連線",
            disconnected: "未連線",
            paired: "已配對",
            connect: "連線",
            disconnect: "中斷連線",
            connecting: "正在連線…",
            disconnecting: "正在中斷連線…",
            connectionFailed: "連線失敗",
            disconnectionFailed: "中斷連線失敗",
            headphones: "耳機",
            selectedAsPrimaryDevice: "已設為主要裝置",
            autoConnectedOnWake: "喚醒時已自動連線",
            batteryLeftShort: "左",
            batteryRightShort: "右",
            batteryCase: "充電盒",
            lowBatteryFormat: "電量偏低 (%d%)",
            noTargetDeviceHeader: "AirSwitch — 未選擇目標裝置",
            targetAudioDevice: "目標音訊裝置",
            noPairedAudioDevicesFound: "找不到已配對的音訊裝置",
            globalShortcutMenuFormat: "全域快速鍵 (%@)…",
            autoConnectOnWake: "喚醒時自動連線（掀開螢幕）",
            autoDisconnectOnSleep: "睡眠時自動中斷連線（闔上螢幕）",
            showFloatingBatteryHUD: "顯示浮動電量 HUD",
            hudAnimations: "HUD 動畫",
            launchAtLogin: "登入時啟動",
            languageMenu: "語言",
            systemDefault: "跟隨系統設定",
            installUpdateFormat: "安裝更新 (%@)…",
            checkForUpdates: "檢查更新…",
            upToDate: "已是最新版本",
            updateCheckFailed: "檢查更新失敗",
            updateFailed: "更新失敗",
            quitAirSwitch: "結束 AirSwitch",
            globalShortcutTitle: "全域快速鍵",
            globalToggleShortcutHeader: "全域切換快速鍵",
            shortcutPrompt: "請按下新的快速鍵組合（按 Esc 取消）",
            shortcutModifierWarning: "需包含 Control (⌃)、Option (⌥) 或 Command (⌘)",
            shortcutReservedFormat: "%@ 已被 macOS 保留，請嘗試其他組合",
            shortcutUpdated: "快速鍵已更新",
            resetToDefaultFormat: "重置為預設值 (%@)",
            cancel: "取消",
            welcomeToAirSwitch: "歡迎使用 AirSwitch",
            choosePrimaryHeadphones: "選擇你的主要耳機",
            refreshDevices: "重新整理裝置",
            refreshPairedDevices: "重新整理已配對裝置",
            emptyPairedDevicesMessage: "找不到已配對的藍牙耳機。\n請在藍牙設定中配對耳機，然後點一下 ↻。",
            continueButton: "繼續",
            continueWithoutDevice: "略過並繼續",
            toggleConnectionAnytime: "隨時快速切換連線",
            selectedAccessibility: "已選取",
            notSelectedAccessibility: "未選取"
        )
    ]
}
