//
//  L10n.swift
//  BeSorted
//

import Foundation
import SwiftUI

/// Lokalizacja UI według preferencji w ustawieniach (nie systemowego Locale).
/// Kluczem jest polski tekst źródłowy; przy języku angielskim zwracane jest tłumaczenie.
enum L10n {
    static func t(_ polish: String) -> String {
        switch AppLanguage.stored {
        case .polish:
            return polish
        case .english:
            return english[polish] ?? polish
        }
    }

    static func format(_ polishTemplate: String, _ args: CVarArg...) -> String {
        let template = t(polishTemplate)
        return String(format: template, locale: Locale(identifier: AppLanguage.stored == .english ? "en_US" : "pl_PL"), arguments: args)
    }

    private static let english: [String: String] = [
        // Tabs & navigation
        "Moje projekty": "My Projects",
        "Aktualny Plan": "Current Plan",
        "Ustawienia": "Settings",
        "Zadania": "Tasks",
        "Aktualne błędy": "Current Bugs",
        "Notatka przyszłości": "Future Note",
        "Szukaj": "Search",
        "Szukaj projektu": "Search project",
        "Brak wyników": "No results",
        "Usuń": "Delete",
        "Edytuj": "Edit",
        "Anuluj": "Cancel",
        "Zamknij": "Close",
        "Tak": "Yes",
        "Nie": "No",
        "Gotowe": "Done",
        "Kopiuj": "Copy",
        "Odrzuć": "Reject",
        "Zatwierdź": "Approve",
        "Priorytet": "Priority",

        // Settings
        "Motyw": "Theme",
        "Język": "Language",
        "Polski": "Polish",
        "Zaloguj się kontem Apple": "Sign in with your Apple Account",
        "Po zalogowaniu projekty i dane synchronizują się przez iCloud. Na nowym urządzeniu wystarczy to samo konto Apple.":
            "After signing in, projects and data sync via iCloud. On a new device, use the same Apple Account.",
        "iCloud gotowy — projekty synchronizują się między urządzeniami.":
            "iCloud is ready — projects sync across your devices.",
        "Brak konta iCloud na tym urządzeniu. Zaloguj się w Ustawieniach → Apple ID.":
            "No iCloud account on this device. Sign in under Settings → Apple ID.",
        "iCloud jest ograniczony na tym urządzeniu.": "iCloud is restricted on this device.",
        "Nie udało się sprawdzić statusu iCloud. Sprawdź sieć i spróbuj ponownie.":
            "Couldn’t check iCloud status. Check your network and try again.",
        "iCloud chwilowo niedostępny. Spróbuj ponownie za chwilę.":
            "iCloud is temporarily unavailable. Try again in a moment.",
        "Nieznany status iCloud.": "Unknown iCloud status.",
        "iCloud jest dostępny, ale synchronizacja projektów jest wyłączona — dane są tylko na tym urządzeniu (skonfiguruj kontener CloudKit).":
            "iCloud is available, but project sync is off — data stays only on this device (set up the CloudKit container).",
        "CloudKit niedostępny — projekty są zapisywane tylko na tym urządzeniu.":
            "CloudKit unavailable — projects are saved only on this device.",
        "Otwórz Ustawienia iCloud": "Open iCloud Settings",
        "Sprawdź ponownie iCloud": "Check iCloud again",
        "Nie udało się odczytać danych konta Apple.": "Couldn’t read Apple Account details.",
        "Zalogowano Apple ID. Włącz iCloud na urządzeniu, aby synchronizować projekty.":
            "Signed in with Apple ID. Turn on iCloud on this device to sync projects.",
        "iCloud i sync": "iCloud & sync",
        "Konto": "Account",
        "Konto Apple": "Apple Account",
        "Nie zalogowano": "Not signed in",
        "Zalogowano": "Signed in",
        "Wyloguj się": "Sign out",
        "Wylogować się?": "Sign out?",
        "Po wylogowaniu aplikacja działa dalej z zapisem lokalnym. Synchronizacja iCloud wróci po ponownym zalogowaniu w Ustawieniach.":
            "After signing out the app keeps working with local saves. iCloud sync comes back once you sign in again from Settings.",
        "Zmień język": "Change language",
        "Wygląd": "Appearance",
        "Ustawienia dodatkowe": "Additional settings",
        "Pastylka menu": "Menu pill",
        "Chowająca się pastylka": "Collapsing menu pill",
        "Przy scrollu w dół pastylka maleje do mini bez ikon. Scroll w górę przywraca pełny rozmiar.":
            "As you scroll down, the pill shrinks to a mini capsule without icons. Scroll up to restore it.",
        "Nagłówek": "Header",
        "Minimalistyczny Nagłówek": "Minimalist Header",
        "Zamiast pełnego paska glass — pastylka za tytułem zakładki (min. 40% Liquid Glass).":
            "Instead of a full glass bar — a pill behind the tab title (min. 40% Liquid Glass).",
        "Synchronizacja CloudKit": "CloudKit sync",
        "Pomiń": "Skip",
        "Uwaga": "Warning",
        "Bez zalogowania się nie będziesz mógł kupić Smart Assistant oraz dane będą zapisywane jedynie lokalnie.":
            "Without signing in you won’t be able to buy Smart Assistant, and data will be saved locally only.",
        "Kontynuuj": "Continue",
        "Zapis lokalny — projekty nie synchronizują się przez iCloud.":
            "Local save only — projects won’t sync via iCloud.",
        "Zaloguj się kontem Apple, aby kupić Smart Assistant.":
            "Sign in with your Apple Account to buy Smart Assistant.",
        "Wymagane konto Apple": "Apple Account required",
        "Zaloguj się": "Sign in",

        "English": "English",
        "Liquid Glass": "Liquid Glass",
        "0% clear": "0% clear",
        "100% regular": "100% regular",
        "Smart Mode": "Smart Mode",
        "Uruchom Smart Mode": "Enable Smart Mode",
        "Jedna pastylka zamiast zakładek i przycisków opcji. Przesuwaj, kliknij, dwuklik AI, przytrzymaj aby przewijać.":
            "One pill instead of tabs and option buttons. Drag, tap, double-tap for AI, hold to scroll.",
        "Maksymalna liczba zadań w Aktualnym Planie.": "Maximum number of tasks in the Current Plan.",
        "Smart Assistant": "Smart Assistant",
        "Aktywuj": "Activate",
        "Zmień": "Change",
        "Nieaktywny": "Inactive",
        "Aktywny: %@": "Active: %@",
        "Aktywny": "Active",
        "Aktywowano Wersję Pro": "Pro Version Activated",
        "Aktywowano Wersję +": "+ Version Activated",
        "Aktywowano Smart Assistant": "Smart Assistant Activated",
        "Użyj": "Use",
        "Kup": "Buy",
        "Kup · %@": "Buy · %@",
        "Zaliczenie poprzedniego planu: −%@": "Previous plan credit: −%@",
        "Odblokowuje też Smart Assistant + oraz Smart Assistant.":
            "Also unlocks Smart Assistant + and Smart Assistant.",
        "Odblokowuje też Smart Assistant.": "Also unlocks Smart Assistant.",
        "Informacje": "Info",
        "Niedostępne do zakupu": "Unavailable to purchase",
        "Ulepsz Smart Assistant": "Upgrade Smart Assistant",
        "„%@” wymaga wyższego modelu.": "“%@” requires a higher model.",
        "Najtańszy model z funkcją „%@”.": "Cheapest model that includes “%@”.",
        "Ten iPhone nie spełnia wymagań sprzętowych tego modelu.":
            "This iPhone doesn’t meet this model’s hardware requirements.",
        "Nie teraz": "Not now",
        "Posiadasz": "Owned",
        "Przejdź do modeli": "Go to models",
        "Zobacz %@": "See %@",
        "Przywróć zakupy": "Restore Purchases",
        "Zakup oczekuje na zatwierdzenie.": "Purchase is pending approval.",
        "Produkty StoreKit są niedostępne.": "StoreKit products are unavailable.",
        "Ten plan wymaga mocniejszego iPhone’a. Twój zakup jest bezpieczny i wróci na sprzęcie, który go obsługuje.":
            "This plan needs a more powerful iPhone. Your purchase is safe and will return on hardware that supports it.",
        "Masz ten plan, ale wymaga mocniejszego iPhone’a. Zakup jest bezpieczny i włączy się na sprzęcie, który go obsługuje.":
            "You own this plan, but it needs a more powerful iPhone. The purchase is safe and will activate on hardware that supports it.",
        "Zakupy zsynchronizowane z App Store": "Purchases synced with the App Store",
        "Wybierz wersję dopasowaną do Twojego iPhone’a.": "Choose the version that matches your iPhone.",
        "Zapoznaj się z Twoją wersją Smart Assistant": "Get to know your Smart Assistant version",
        "Zapoznaj się z funkcjami tego modelu": "Get to know this model’s features",
        "Krótki przewodnik po funkcjach · %@": "A short guide to features · %@",
        "Zapoznaj się": "Get to know it",
        "Odłącz pastylkę AI i zadawaj pytania o projekty — asystent odpowiada w kontekście Twoich danych.":
            "Detach the AI pill and ask about your projects — the assistant answers in your data’s context.",
        "Wskaż projekt, a AI przygotuje zwięzłe streszczenie: postęp, zadania i to, co warto wiedzieć.":
            "Pick a project and AI prepares a concise summary: progress, tasks, and what matters.",
        "Jednym tapnięciem skróć długi opis projektu do czytelnego podsumowania, bez utraty sensu.":
            "In one tap, shorten a long project description into a clear summary without losing meaning.",
        "AI proponuje konkretne kolejne zadania dopasowane do opisu, rdzenia i plików kontekstu.":
            "AI suggests concrete next tasks matched to the description, project core, and context files.",
        "Lokalnie lub na Pro: 7 konkretnych zadań dopasowanych do opisu, typu projektu i rdzenia.":
            "Locally or on Pro: 7 concrete tasks matched to the description, project type, and core.",
        "Uzupełnij Aktualny Plan zadaniami z priorytetowych projektów — AI dobiera to, co najważniejsze.":
            "Fill Current Plan with tasks from priority projects — AI picks what matters most.",
        "Gdy plan jest pełny, AI rozbija wybrane zadanie na mniejsze, wykonalne kroki.":
            "When the plan is full, AI breaks a chosen task into smaller, doable steps.",
        "Szybkie przypomnienie całego projektu: nazwa, typ, ocena, postęp, błędy i plany na przyszłość.":
            "A quick project reminder: name, type, rating, progress, bugs, and future plans.",
        "Jedna konkretna rekomendacja: co zrobić teraz, na podstawie otwartych zadań i notatek.":
            "One concrete recommendation: what to do now, based on open tasks and notes.",
        "Za mało detali projektu — uzupełnij konkretny opis albo Rdzeń Projektowy, zanim zaproponuję zadania.":
            "Not enough project details — add a concrete description or fill Project Core before proposing tasks.",
        "Za mało detali projektu — uzupełnij konkretny opis, zanim zaproponuję zadania.":
            "Not enough project details — add a concrete description before proposing tasks.",
        "Za mało informacji o projekcie — uzupełnij konkretny opis i Rdzeń Projektowy, zanim użyjesz tej akcji AI.":
            "Not enough project information — add a clear description and Project Core before using this AI action.",
        "Za mało informacji o projekcie — uzupełnij konkretny opis, zanim użyjesz tej akcji AI.":
            "Not enough project information — add a clear description before using this AI action.",
        "Za mało informacji w opisie, żeby go streścić.":
            "Not enough information in the description to summarize.",
        "Umiejętności": "Skills",
        "Asystent Q&A": "Q&A Assistant",
        "Streść opis": "Summarize description",
        "Ułóż Aktualny Plan": "Fill Current Plan",
        "Rozbij zadanie": "Break down task",
        "Aktywuj Smart Assistant w Ustawieniach.": "Activate Smart Assistant in Settings.",
        "„%@” wymaga Smart Assistant Pro.": "“%@” requires Smart Assistant Pro.",
        "„%@” wymaga Smart Assistant + lub Pro.": "“%@” requires Smart Assistant + or Pro.",
        "„%@” jest niedostępne w %@.": "“%@” is unavailable in %@.",
        "Czarny": "Black",
        "Biały": "White",
        "Pomarańczowy": "Orange",
        "Ciemnoniebieski": "Dark Blue",
        "Srebrny": "Silver",
        "Jasnoniebieski": "Light Blue",
        "Wiśniowy": "Cherry",

        "Dane": "Data",
        "Resetuj": "Reset",
        "Zresetować dane?": "Reset data?",
        "Usuwa projekty, zadania i ustawienia. Wykupione modele Smart Assistant zostają.":
            "Deletes projects, tasks, and settings. Purchased Smart Assistant models are kept.",
        "Usuwa wszystkie projekty i ustawienia. Modele Smart Assistant pozostają bez zmian.":
            "Deletes all projects and settings. Smart Assistant models stay unchanged.",

        // Projects
        "Dodaj projekt": "Add Project",
        "Dodaj zadania": "Add tasks",
        "Rozbij zadania": "Break down tasks",
        "Plan jest pełny.": "The plan is full.",
        "Brak zadań w planie.": "No tasks in the plan.",
        "Nowy projekt": "New Project",
        "Nazwa projektu": "Project name",
        "Opis projektu": "Project description",
        "Rodzaj projektu": "Project type",
        "Kluczowość projektu": "Project importance",
        "Zapisz projekt": "Save Project",
        "Dodano do listy": "Added to the list",
        "Wpisz nazwę": "Enter a name",
        "Gra": "Game",
        "Opowiadanie": "Story",
        "Rysunek": "Drawing",
        "Aplikacja": "App",
        "Szkoła": "School",
        "Mało znaczący projekt": "Low-importance project",
        "Skromny projekt, ale robiony z chęciami": "Modest project, but made with care",
        "Średni projekt": "Medium project",
        "W miarę duży projekt, w który angażuję się często": "Fairly large project I work on often",
        "Bardzo ważny projekt, który jest dla mnie głównym celem": "Very important project — my main goal",
        "Sortowanie": "Sort",
        "Data dodania": "Date added",
        "Gwiazdki (od najwyższych)": "Stars (highest first)",
        "Usuwanie": "Delete",
        "Wybierz projekt do streszczenia": "Choose a project to summarize",
        "Brak projektów do analizy.": "No projects to analyze.",
        "Brak streszczenia.": "No summary.",
        "Najbardziej krytyczne błędy": "Most critical bugs",

        // Tasks
        "Dodaj zadanie": "Add Task",
        "Nowe zadanie": "New Task",
        "Edytuj zadanie": "Edit Task",
        "Nazwa zadania": "Task name",
        "Opis zadania": "Task description",
        "Rodzaj zadania": "Task type",
        "Kluczowość zadania": "Task importance",
        "Zapisz zadanie": "Save Task",
        "Zapisz zmiany": "Save changes",
        "Wpisz nazwę zadania": "Enter a task name",
        "Usuń zadanie": "Delete task",
        "Zadanie jest zrobione": "Task is done",
        "Mało znaczące zadanie": "Low-importance task",
        "Skromne zadanie, ale warte zrobienia": "Modest task, but worth doing",
        "Średnie zadanie": "Medium task",
        "Ważne zadanie, którym zajmuję się często": "Important task I work on often",
        "Kluczowe zadanie, główny priorytet projektu": "Key task — the project's main priority",
        "Mało istotny": "Low priority",
        "Brak otwartych zadań.": "No open tasks.",
        "Brak dostępnych zadań": "No available tasks",
        "Brak opisu — kliknij dwukrotnie, aby dodać": "No description — double-tap to add",
        "Zadania (od najważniejszych)": "Tasks (most important first)",
        "Ocena wagi": "Importance rating",
        "W aktualnym planie": "In Current Plan",
        "W kolejce do planu": "Queued for the plan",
        "Kolejka (wejdą po zwolnieniu miejsca)": "Queue (join when a slot frees up)",
        "%d/%d zadań": "%d/%d tasks",
        "Dodano %d zadań do planu.": "Added %d tasks to the plan.",
        "Dodano %d zadań.": "Added %d tasks.",
        "AI nie znalazło zadań do planu.": "AI found no tasks for the plan.",
        "AI układa Aktualny Plan…": "AI is building the Current Plan…",
        "AI dobiera najważniejsze zadania…": "AI is picking the most important tasks…",
        "Oznacz projekty jako priorytetowe, żeby AI mogło dobrać zadania.":
            "Mark projects as priority so AI can pick tasks.",
        "Brak istniejących zadań do dodania. Użyj „Zaproponuj zadania” w projekcie.":
            "No existing tasks to add. Use “Suggest Tasks” in the project.",

        // Task kinds
        "Mechanika": "Mechanics",
        "Materiały": "Materials",
        "Poprawka": "Fix",
        "Inne": "Other",
        "Szkic": "Sketch",
        "Dopracowanie": "Polish",
        "Element": "Element",
        "Postać": "Character",
        "Scena": "Scene",
        "Zadanie": "Assignment",
        "Nauka": "Learning",

        // Bugs
        "Dodaj błąd": "Add Bug",
        "Nowy błąd": "New Bug",
        "Tytuł błędu": "Bug title",
        "Opis błędu": "Bug description",
        "Zapisz błąd": "Save Bug",
        "Wpisz tytuł": "Enter a title",
        "Brak błędów": "No bugs",
        "Brak błędów.": "No bugs.",
        "Brak opisu skutku.": "No impact description.",
        "Czy są jakieś błędy do poprawy?": "Any bugs to fix?",
        "Błąd nie pozwala na odpalenie gry": "Bug prevents launching the game",
        "Błąd przeszkadza w całej rozgrywce": "Bug disrupts the whole playthrough",
        "Błąd przeszkadza w niektórych zadaniach": "Bug interferes with some tasks",
        "Czasami się pokazuje, ale nie przeszkadza w grze": "It sometimes appears but doesn't block play",
        "Waga %d/5": "Severity %d/5",

        // Future notes
        "Dodaj notatkę": "Add Note",
        "Nowa notatka": "New Note",
        "Przypomnij projekt": "Remind Me About the Project",
        "Co mogę zrobić teraz": "What Can I Do Now",
        "Przypomnienie projektu": "Project Reminder",
        "Typ gry": "Game type",
        "Typ projektu": "Project type",
        "Ocena projektu": "Project rating",
        "AI przypomina projekt…": "AI is recalling the project…",
        "AI analizuje, co możesz zrobić…": "AI is analyzing what you can do…",

        // AI
        "Streść projekt": "Summarize Project",
        "Zapomniany projekt": "Forgotten Project",
        "Priorytetyzuj": "Prioritize",
        "Ustaw jako priorytetowy": "Mark as Priority",
        "Nie znaleziono zapomnianego projektu do oznaczenia jako priorytetowy.":
            "No forgotten project found to mark as priority.",
        "Wskaż projekt, który został zaniedbany mimo potencjału — i zaproponuj oznaczenie go jako priorytetowy.":
            "Find a neglected project that still has potential — and suggest marking it as priority.",
        "Oceń projekt": "Evaluate Project",
        "Luki w projekcie": "Project Gaps",
        "Krytyka projektu": "Project Critique",
        "Na Pro: krytyczna ocena sensu, oryginalności i przeładowania. Na +: „Luki w projekcie” — audyt kompletności.":
            "On Pro: a critical review of sense, originality and bloat. On +: “Project Gaps” — a completeness audit.",
        "AI ocenia projekt…": "AI is evaluating the project…",
        "Aby ocenić projekt, uzupełnij opis i Rdzeń Projektowy.":
            "To evaluate the project, fill in the description and Project Core.",
        "Aby ocenić projekt, uzupełnij opis projektu.":
            "To evaluate the project, fill in the project description.",
        "Aby ocenić projekt, uzupełnij Rdzeń Projektowy.":
            "To evaluate the project, fill in the Project Core.",
        "Streszczenie projektu": "Project Summary",
        "Zaproponuj zadania": "Suggest Tasks",
        "Streszczenie AI": "AI Summary",
        "Propozycje AI": "AI Suggestions",
        "7 kluczowych elementów projektu": "7 key project elements",
        "AI czyta opis…": "AI is reading the description…",
        "AI czyta projekt…": "AI is reading the project…",
        "AI nie zaproponowało zadań.": "AI suggested no tasks.",
        "AI przygotowuje podsumowanie…": "AI is preparing a summary…",
        "AI zbyt długo przygotowywało odpowiedź. Spróbuj ponownie.":
            "AI took too long to respond. Please try again.",
        "AI rozbija zadanie…": "AI is breaking down the task…",
        "Oryginalny opis projektu pozostaje nietknięty, dopóki go nie zastąpisz.":
            "The original project description stays untouched until you replace it.",
        "Zastąp oryginalny opis": "Replace original description",
        "Przywróć oryginalny tekst": "Restore original text",
        "Przywrócono oryginalny opis.": "Original description restored.",
        "Zastąpiono opis streszczeniem.": "Description replaced with the summary.",
        "Skopiowano streszczenie.": "Summary copied.",
        "Zapytaj AI…": "Ask AI…",
        "Nie mam odpowiedzi.": "No answer.",
        "Nie udało się uzyskać odpowiedzi.": "Couldn't get a response.",
        "Generuję…": "Generating…",
        "Nowa lista": "New list",
        "Jak wykonać to zadanie": "How to complete this task",
        "Brak konkretnych punktów — spróbuj wygenerować nową listę.":
            "No concrete points — try generating a new list.",
        "Wybierz zadanie, które AI ma rozbić na kroki": "Choose a task for AI to break into steps",
        "Zatwierdź modyfikację": "Confirm edit",
        "Na zakładce Aktualny Plan mocno przeciągnij w górę, aby otworzyć AI":
            "On the Current Plan tab, drag strongly upward to open AI",

        // Context / core
        "Pliki kontekstowe": "Context Files",
        "Pliki kontekstu": "Context Files",
        "Rdzeń Projektowy": "Project Core",
        "Dodaj pliki": "Add Files",
        "Dodaj pliki kluczowe dla AI — np. dokumentację silnika, design doc albo notatki o mechanikach.":
            "Add key files for AI — e.g. engine docs, a design doc, or mechanics notes.",
        "Dodaj pliki kluczowe dla AI — np. aktualny tekst opowiadania z Notatek albo zarys świata.":
            "Add key files for AI — e.g. the current story draft or a world outline.",
        "Dodaj pliki kluczowe dla AI — np. brief, listę elementów albo opis stylu.":
            "Add key files for AI — e.g. a brief, element list, or style notes.",
        "Dodaj pliki kluczowe dla AI — np. brief produktu, specyfikację funkcji albo plan ekranów.":
            "Add key files for AI — e.g. a product brief, feature spec, or screen plan.",
        "Dodaj pliki kluczowe dla AI — np. notatki, wytyczne lub materiały do projektu.":
            "Add key files for AI — e.g. notes, guidelines, or project materials.",
        "Te pliki służą głównie AI, żeby lepiej rozumiało środowisko projektu.":
            "These files mainly help AI understand the project context.",
        "Brak plików. Dodaj tekstowe dokumenty istotne dla projektu.":
            "No files. Add text documents that matter for the project.",
        "Dodano 1 plik kontekstowy.": "Added 1 context file.",
        "Dodano %d pliki kontekstowe.": "Added %d context files.",
        "Rdzeń projektowy jest dostępny dla projektów typu Gra.":
            "Project Core is available for Game projects.",
        "Rdzeń projektowy jest dostępny dla projektów typu Gra i Opowiadanie.":
            "Project Core is available for Game and Story projects.",
        "Rdzeń projektowy jest dostępny dla projektów typu Gra, Opowiadanie i Rysunek.":
            "Project Core is available for Game, Story, and Drawing projects.",
        "Rdzeń projektowy jest dostępny dla projektów typu Gra, Opowiadanie, Rysunek i Aplikacja.":
            "Project Core is available for Game, Story, Drawing, and App projects.",
        "Technika i Narzędzia": "Technique & Tools",
        "Główny Motyw": "Main Motif",
        "Cel i Emocja": "Goal & Emotion",
        "Definicja Ukończenia": "Completion Definition",
        "Skala i przestrzeń": "Scale & Space",
        "Szkic ołówkiem": "Pencil sketch",
        "Akwarele": "Watercolor",
        "Lineart": "Lineart",
        "Digital painting": "Digital painting",
        "Pastele": "Pastels",
        "Manga/Anime": "Manga/Anime",
        "Realizm": "Realism",
        "Kreskówka": "Cartoon",
        "Komiksowy": "Comic",
        "Koncept Art": "Concept Art",
        "Minimalizm": "Minimalism",
        "Jedna postać / proste tło": "Single character / simple background",
        "Rozbudowana scena": "Large detailed scene",
        "Skupienie na jednej postaci lub elemencie na prostym tle":
            "Focus on one character or element on a simple background",
        "Wielka, detaliczna scena z wieloma postaciami / elementami":
            "A large, detailed scene with many characters / elements",
        "Co na rysunku jest najważniejszym elementem projektu…":
            "What is the most important element of this drawing…",
        "Co ma przedstawiać ten rysunek, jakie przesłanie lub emocje…":
            "What should this drawing convey — message or emotions…",
        "Kiedy projekt ma być uznany za zakończony…":
            "When should this project be considered finished…",
        "Główne Mechaniki": "Core Mechanics",
        "Gameloop": "Gameloop",
        "Cele Gracza": "Player Goals",
        "Warunki Zakończenia Gry / Wygranej": "Win / End Conditions",
        "Gatunek": "Genre",
        "Struktura": "Structure",
        "Motyw przewodni": "Central Theme",
        "Typowa Akcja": "Typical Action",
        "Cel Bohatera": "Hero’s Goal",
        "Finał": "Finale",
        "Sposób opowiadania": "Narration Style",
        "Z perspektywy bohatera": "From the hero’s perspective",
        "Narrator": "Narrator",
        "Chaotyczna": "Chaotic",
        "Liniowa": "Linear",
        "Opisz główne mechaniki gry…": "Describe the main game mechanics…",
        "Opisz główny gameloop…": "Describe the main gameloop…",
        "Czego gracz chce dokonać…": "What the player wants to achieve…",
        "Kiedy gra się kończy lub kiedy wygrywasz…": "When the game ends or when you win…",
        "Co jest unikalnego dla tego opowiadania…": "What is unique about this story…",
        "Co bohaterowie / bohater robi przez większość czasu…":
            "What the heroes / hero do most of the time…",
        "Główne pragnienie / plan bohaterów lub bohatera…":
            "The main desire / plan of the heroes or hero…",
        "Co musi się wydarzyć i jak wygląda sam finał…":
            "What must happen and what the finale looks like…",
        "Najważniejsze funkcje — czym aplikacja się wyróżnia…":
            "The most important features — what makes the app stand out…",
        "Jak użytkownik ma używać aplikacji — jaka jest pętla użytkowania…":
            "How the user will use the app — what the usage loop looks like…",
        "Jaki problem lub problemy aplikacja ma rozwiązywać…":
            "What problem(s) the app should solve…",
        "Kluczowe Funkcjonalności": "Key Features",
        "Ścieżka Użytkownika": "User Path",
        "Główny problem": "Main Problem",
        "Kategoria aplikacji": "App Category",
        "Forma projektu": "Project Form",
        "Cel projektu": "Project Goal",
        "Co ma przekazać ten projekt…": "What this project should convey…",
        "Główna zawartość": "Main Content",
        "Czego dotyczy projekt…": "What the project is about…",
        "Przedmiot Szkolny": "School Subject",
        "Wpisz przedmiot…": "Enter the subject…",
        "Sposób realizacji": "Execution Mode",
        "Kryterium końcowe": "Final Criterion",
        "Co musi mieć projekt, aby został uznany za skończony…":
            "What the project must have to be considered finished…",
        "%@ · %d znaków": "%@ · %d characters",

        // Smart Mode extras
        "Jedna pastylka": "One pill",
    ]
}

extension String {
    /// Tłumaczy polski tekst UI według wybranego języka aplikacji.
    var l10n: String { L10n.t(self) }
}

extension AppAppearance {
    func t(_ polish: String) -> String { L10n.t(polish) }
}

/// Sformatowany wynik AI: nagłówki, akapity, listy, pogrubienia.
struct AIFormattedResultText: View {
    let text: String
    var primary: Color
    var secondary: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let title):
                    Text(title)
                        .font(headingFont(level))
                        .foregroundStyle(primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, level == 1 ? 4 : 2)

                case .paragraph(let runs):
                    formattedLine(runs, font: .body, color: secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                case .bullet(let runs):
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body.weight(.bold))
                            .foregroundStyle(primary)
                        formattedLine(runs, font: .body, color: secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                case .numbered(let index, let runs):
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index).")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(primary)
                            .frame(minWidth: 22, alignment: .trailing)
                        formattedLine(runs, font: .body, color: secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                case .labeled(let label, let value):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondary.opacity(0.9))
                            .textCase(.uppercase)
                            .tracking(0.4)
                        Text(value)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(primary.opacity(0.08))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func formattedLine(_ runs: [InlineRun], font: Font, color: Color) -> some View {
        // Składamy Text z mieszanym stylem (bold / regular).
        // iOS 26: `Text + Text` jest wycofane na rzecz interpolacji — każdy run
        // zachowuje własny font i kolor, więc wygląd jest identyczny.
        runs.reduce(Text("")) { partial, run in
            let piece = Text(run.text)
                .font(run.bold ? font.weight(.bold) : font.weight(.regular))
                .foregroundColor(run.bold ? primary : color)
            return Text("\(partial)\(piece)")
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.weight(.bold)
        case 2: return .title3.weight(.bold)
        default: return .headline.weight(.semibold)
        }
    }

    private enum Block {
        case heading(level: Int, title: String)
        case paragraph([InlineRun])
        case bullet([InlineRun])
        case numbered(Int, [InlineRun])
        case labeled(label: String, value: String)
    }

    private struct InlineRun {
        var text: String
        var bold: Bool
    }

    private var blocks: [Block] {
        Self.parse(text)
    }

    private static func parse(_ raw: String) -> [Block] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var blocks: [Block] = []
        var paragraphBuffer: [String] = []

        func flushParagraph() {
            let joined = paragraphBuffer
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            paragraphBuffer = []
            guard !joined.isEmpty else { return }
            blocks.append(.paragraph(inlineRuns(joined)))
        }

        for line in trimmed.components(separatedBy: .newlines) {
            let stripped = line.trimmingCharacters(in: .whitespaces)

            if stripped.isEmpty {
                flushParagraph()
                continue
            }

            if stripped.hasPrefix("### ") {
                flushParagraph()
                blocks.append(.heading(level: 3, title: cleanHeading(String(stripped.dropFirst(4)))))
                continue
            }
            if stripped.hasPrefix("## ") {
                flushParagraph()
                blocks.append(.heading(level: 2, title: cleanHeading(String(stripped.dropFirst(3)))))
                continue
            }
            if stripped.hasPrefix("# ") {
                flushParagraph()
                blocks.append(.heading(level: 1, title: cleanHeading(String(stripped.dropFirst(2)))))
                continue
            }

            if let numberedTitle = numberedHeading(stripped), stripped.count <= 90 {
                flushParagraph()
                blocks.append(.heading(level: 3, title: cleanHeading(numberedTitle)))
                continue
            }

            if stripped.hasPrefix("- ") || stripped.hasPrefix("* ") || stripped.hasPrefix("• ") {
                flushParagraph()
                let content = String(stripped.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.bullet(inlineRuns(content)))
                continue
            }

            if let (num, content) = numberedItem(stripped) {
                flushParagraph()
                blocks.append(.numbered(num, inlineRuns(content)))
                continue
            }

            if let labeled = labeledField(stripped) {
                flushParagraph()
                blocks.append(.labeled(label: labeled.label, value: labeled.value))
                continue
            }

            paragraphBuffer.append(stripped)
        }
        flushParagraph()

        if blocks.isEmpty {
            // Fallback: dziel długi tekst na akapity co ~2–3 zdania.
            return softSplitParagraphs(trimmed).map { .paragraph(inlineRuns($0)) }
        }
        return blocks
    }

    private static func softSplitParagraphs(_ text: String) -> [String] {
        let sentences = text
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard sentences.count > 1 else { return [text] }

        var paragraphs: [String] = []
        var chunk: [String] = []
        for (index, sentence) in sentences.enumerated() {
            chunk.append(sentence.hasSuffix(".") ? sentence : sentence + ".")
            if chunk.count >= 2 || index == sentences.count - 1 {
                paragraphs.append(chunk.joined(separator: " "))
                chunk = []
            }
        }
        return paragraphs.isEmpty ? [text] : paragraphs
    }

    private static func cleanHeading(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func inlineRuns(_ raw: String) -> [InlineRun] {
        var runs: [InlineRun] = []
        var remaining = raw
        while let start = remaining.range(of: "**") {
            let before = String(remaining[..<start.lowerBound])
            if !before.isEmpty {
                runs.append(InlineRun(text: before, bold: false))
            }
            remaining = String(remaining[start.upperBound...])
            if let end = remaining.range(of: "**") {
                let bold = String(remaining[..<end.lowerBound])
                if !bold.isEmpty {
                    runs.append(InlineRun(text: bold, bold: true))
                }
                remaining = String(remaining[end.upperBound...])
            } else {
                runs.append(InlineRun(text: "**" + remaining, bold: false))
                remaining = ""
            }
        }
        if !remaining.isEmpty {
            runs.append(InlineRun(text: remaining, bold: false))
        }
        return runs.isEmpty ? [InlineRun(text: raw, bold: false)] : runs
    }

    private static func numberedHeading(_ line: String) -> String? {
        let pattern = #"^(\d+)[\.\)]\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges >= 3,
              let titleRange = Range(match.range(at: 2), in: line)
        else { return nil }
        let title = String(line[titleRange]).trimmingCharacters(
            in: CharacterSet(charactersIn: ":").union(.whitespaces)
        )
        if title.count <= 80, !title.contains(". ") {
            return title
        }
        return nil
    }

    private static func numberedItem(_ line: String) -> (Int, String)? {
        let pattern = #"^(\d+)[\.\)]\s+(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges >= 3,
              let numRange = Range(match.range(at: 1), in: line),
              let textRange = Range(match.range(at: 2), in: line),
              let num = Int(line[numRange])
        else { return nil }
        let content = String(line[textRange]).trimmingCharacters(in: .whitespaces)
        // Dłuższe linie = pozycje listy, nie nagłówki sekcji.
        guard content.count > 40 || content.contains(". ") else { return nil }
        return (num, content)
    }

    /// Linie w stylu `**Nazwa projektu:** Syncly` albo `Nazwa projektu: Syncly`.
    private static func labeledField(_ line: String) -> (label: String, value: String)? {
        let cleaned = line
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = cleaned.firstIndex(of: ":") else { return nil }
        let label = cleaned[..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = cleaned[cleaned.index(after: colon)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, !value.isEmpty, label.count <= 40, !label.contains(".") else {
            return nil
        }
        let known: Set<String> = [
            "Nazwa projektu", "Project name",
            "Typ", "Type", "Typ projektu", "Project type", "Typ gry", "Game type",
            "Ocena", "Rating", "Ocena projektu", "Project rating",
            "Kluczowość", "Importance"
        ]
        guard known.contains(label) else { return nil }
        return (label, value)
    }
}
