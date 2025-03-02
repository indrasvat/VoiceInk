import SwiftUI
import SwiftData

struct TranscriptionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var expandedTranscription: Transcription?
    @State private var selectedTranscriptions: Set<Transcription> = []
    @State private var showDeleteConfirmation = false
    
    // Pagination states
    @State private var displayedTranscriptions: [Transcription] = []
    @State private var currentPage = 0
    private let pageSize = 20
    @State private var hasMoreContent = true
    @State private var isLoading = false
    @State private var totalCount: Int = 0
    
    // Add a Query for latest transcriptions
    @Query(sort: \Transcription.timestamp, order: .reverse) private var latestTranscriptions: [Transcription]
    
    // Optimized query descriptor
    private var queryDescriptor: FetchDescriptor<Transcription> {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\Transcription.timestamp, order: .reverse)]
        )
        
        if !searchText.isEmpty {
            descriptor.predicate = #Predicate<Transcription> { transcription in
                transcription.text.localizedStandardContains(searchText) ||
                (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)
            }
        }
        
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = currentPage * pageSize
        
        return descriptor
    }
    
    // Optimized count descriptor
    private var countDescriptor: FetchDescriptor<Transcription> {
        var descriptor = FetchDescriptor<Transcription>()
        
        if !searchText.isEmpty {
            descriptor.predicate = #Predicate<Transcription> { transcription in
                transcription.text.localizedStandardContains(searchText) ||
                (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)
            }
        }
        
        return descriptor
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if displayedTranscriptions.isEmpty && !isLoading {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(displayedTranscriptions) { transcription in
                            TranscriptionCard(
                                transcription: transcription, 
                                isExpanded: expandedTranscription == transcription,
                                isSelected: selectedTranscriptions.contains(transcription),
                                onDelete: { deleteTranscription(transcription) },
                                onToggleSelection: { toggleSelection(transcription) }
                            )
                            .onTapGesture {
                                withAnimation {
                                    if expandedTranscription == transcription {
                                        expandedTranscription = nil
                                    } else {
                                        expandedTranscription = transcription
                                    }
                                }
                            }
                        }
                        
                        if hasMoreContent {
                            Button(action: {
                                loadMoreContentIfNeeded()
                            }) {
                                HStack(spacing: 8) {
                                    if isLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text(isLoading ? "Loading..." : "Load More")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.windowBackgroundColor).opacity(0.4))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                            .padding(.top, 12)
                        }
                    }
                    .padding(24)
                }
                .padding(.vertical, 16)
            }
            
            if !selectedTranscriptions.isEmpty {
                selectionToolbar
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Delete Selected Items?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedTranscriptions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Are you sure you want to delete \(selectedTranscriptions.count) item\(selectedTranscriptions.count == 1 ? "" : "s")?")
        }
        .onAppear {
            Task {
                await loadInitialContent()
            }
        }
        .onChange(of: searchText) { _, _ in
            Task {
                await resetPagination()
                await loadInitialContent()
            }
        }
        // Add onChange handler for latestTranscriptions
        .onChange(of: latestTranscriptions) { _, newTranscriptions in
            handleNewTranscriptions(newTranscriptions)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search transcriptions", text: $searchText)
                .font(.system(size: 16, weight: .regular, design: .default))
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(12)
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .cornerRadius(10)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No transcriptions found")
                .font(.system(size: 24, weight: .semibold, design: .default))
            Text("Your history will appear here")
                .font(.system(size: 18, weight: .regular, design: .default))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor).opacity(0.4))
        .padding(24)
    }
    
    private var selectionToolbar: some View {
        HStack {
            Spacer()
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            
            if selectedTranscriptions.count < totalCount {
                Button("Select All") {
                    Task {
                        await selectAllTranscriptions()
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Button("Deselect All") {
                    selectedTranscriptions.removeAll()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(Color(.windowBackgroundColor).opacity(0.4))
    }
    
    private func loadInitialContent() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Get total count for pagination
            totalCount = try modelContext.fetchCount(countDescriptor)
            
            // Fetch initial page
            currentPage = 0
            let items = try modelContext.fetch(queryDescriptor)
            
            await MainActor.run {
                displayedTranscriptions = items
                hasMoreContent = items.count == pageSize && totalCount > pageSize
            }
        } catch {
            print("Error loading transcriptions: \(error)")
        }
    }
    
    private func loadMoreContentIfNeeded() {
        guard !isLoading && hasMoreContent else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                currentPage += 1
                let newItems = try modelContext.fetch(queryDescriptor)
                
                await MainActor.run {
                    displayedTranscriptions.append(contentsOf: newItems)
                    hasMoreContent = newItems.count == pageSize && 
                        displayedTranscriptions.count < totalCount
                }
            } catch {
                print("Error loading more transcriptions: \(error)")
                currentPage -= 1
            }
        }
    }
    
    private func resetPagination() async {
        await MainActor.run {
            currentPage = 0
            displayedTranscriptions = []
            hasMoreContent = true
            isLoading = false
            totalCount = 0
        }
    }
    
    private func deleteTranscription(_ transcription: Transcription) {
        // First delete the audio file if it exists
        if let urlString = transcription.audioFileURL,
           let url = URL(string: urlString) {
            try? FileManager.default.removeItem(at: url)
        }
        
        modelContext.delete(transcription)
        if expandedTranscription == transcription {
            expandedTranscription = nil
        }
        
        // Remove from selection if selected
        selectedTranscriptions.remove(transcription)
        
        // Refresh the view
        Task {
            try? await modelContext.save()
            await loadInitialContent()
        }
    }
    
    private func deleteSelectedTranscriptions() {
        // Delete audio files and transcriptions
        for transcription in selectedTranscriptions {
            if let urlString = transcription.audioFileURL,
               let url = URL(string: urlString) {
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(transcription)
            if expandedTranscription == transcription {
                expandedTranscription = nil
            }
        }
        
        // Clear selection
        selectedTranscriptions.removeAll()
        
        // Save changes and refresh
        Task {
            try? await modelContext.save()
            await loadInitialContent()
        }
    }
    
    private func toggleSelection(_ transcription: Transcription) {
        if selectedTranscriptions.contains(transcription) {
            selectedTranscriptions.remove(transcription)
        } else {
            selectedTranscriptions.insert(transcription)
        }
    }
    
    // Add new function to handle latest transcriptions
    private func handleNewTranscriptions(_ newTranscriptions: [Transcription]) {
        Task {
            // Get the current total count
            if let count = try? modelContext.fetchCount(countDescriptor) {
                totalCount = count
            }
            
            // Only update if we're on the first page and not searching
            if currentPage == 0 && searchText.isEmpty {
                // Take only the first pageSize items to maintain pagination
                let newDisplayed = Array(newTranscriptions.prefix(pageSize))
                displayedTranscriptions = newDisplayed
                hasMoreContent = newTranscriptions.count > pageSize
            }
        }
    }
    
    // Add new function to select all transcriptions
    private func selectAllTranscriptions() async {
        do {
            // Create a descriptor without pagination limits
            var allDescriptor = FetchDescriptor<Transcription>()
            if !searchText.isEmpty {
                allDescriptor.predicate = #Predicate<Transcription> { transcription in
                    transcription.text.localizedStandardContains(searchText) ||
                    (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)
                }
            }
            
            // Fetch all transcriptions
            let allTranscriptions = try modelContext.fetch(allDescriptor)
            selectedTranscriptions = Set(allTranscriptions)
        } catch {
            print("Error selecting all transcriptions: \(error)")
        }
    }
}

struct CircularCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .font(.system(size: 18))
        }
        .buttonStyle(.plain)
    }
}

struct TranscriptionCard: View {
    let transcription: Transcription
    let isExpanded: Bool
    let isSelected: Bool
    let onDelete: () -> Void
    let onToggleSelection: () -> Void
    @State private var showOriginalCopiedAlert = false
    @State private var showEnhancedCopiedAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox in macOS style
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggleSelection() }
            ))
            .toggleStyle(CircularCheckboxStyle())
            .labelsHidden()
            
            VStack(alignment: .leading, spacing: 8) {
                // Header with date and duration
                HStack {
                    Text(transcription.timestamp, style: .date)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                    Spacer()
                    
                    Text(formatDuration(transcription.duration))
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
                
                // Original text section
                VStack(alignment: .leading, spacing: 8) {
                    if isExpanded {
                        HStack {
                            Text("Original")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                copyToClipboard(transcription.text)
                                showOriginalCopiedAlert = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showOriginalCopiedAlert ? "checkmark" : "doc.on.doc")
                                    Text(showOriginalCopiedAlert ? "Copied!" : "Copy")
                                }
                                .foregroundColor(showOriginalCopiedAlert ? .green : .blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(showOriginalCopiedAlert ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.2), value: showOriginalCopiedAlert)
                        }
                    }
                    
                    Text(transcription.text)
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .lineLimit(isExpanded ? nil : 2)
                        .lineSpacing(2)
                }
                
                // Enhanced text section (only when expanded)
                if isExpanded, let enhancedText = transcription.enhancedText {
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.blue)
                                Text("Enhanced")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                            Button {
                                copyToClipboard(enhancedText)
                                showEnhancedCopiedAlert = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showEnhancedCopiedAlert ? "checkmark" : "doc.on.doc")
                                    Text(showEnhancedCopiedAlert ? "Copied!" : "Copy")
                                }
                                .foregroundColor(showEnhancedCopiedAlert ? .green : .blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(showEnhancedCopiedAlert ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                                )
                            }
                            .buttonStyle(.plain)
                            .animation(.easeInOut(duration: 0.2), value: showEnhancedCopiedAlert)
                        }
                        
                        Text(enhancedText)
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .lineSpacing(2)
                    }
                }
                
                // Audio player (if available)
                if isExpanded, let urlString = transcription.audioFileURL,
                   let url = URL(string: urlString),
                   FileManager.default.fileExists(atPath: url.path) {
                    Divider()
                        .padding(.vertical, 8)
                    AudioPlayerView(url: url)
                }
                
                // Timestamp (only when expanded)
                if isExpanded {
                    HStack {
                        Text(transcription.timestamp, style: .time)
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor).opacity(0.4))
        )
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        .contextMenu {
            if let enhancedText = transcription.enhancedText {
                Button {
                    copyToClipboard(enhancedText)
                    showEnhancedCopiedAlert = true
                } label: {
                    Label("Copy Enhanced", systemImage: "doc.on.doc")
                }
            }
            
            Button {
                copyToClipboard(transcription.text)
                showOriginalCopiedAlert = true
            } label: {
                Label("Copy Original", systemImage: "doc.on.doc")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onChange(of: showOriginalCopiedAlert) { _, isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showOriginalCopiedAlert = false
                }
            }
        }
        .onChange(of: showEnhancedCopiedAlert) { _, isShowing in
            if isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showEnhancedCopiedAlert = false
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let success = ClipboardManager.copyToClipboard(text)
        if !success {
            print("Failed to copy text to clipboard")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
