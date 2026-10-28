import AtomicXCore
import SwiftUI

struct GroupCallMemberPickerViewImpl: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @StateObject private var viewModel: MentionMemberPickerViewModel
    @State private var selectedMembers: Set<String> = []
    @State private var scrollTarget: String?
    @State private var scrubbingLetter: String?
    @State private var sectionScrollOffset: CGFloat = 0

    let pageTitle: String
    let onConfirm: ([String]) -> Void

    private static let maxSelectableCount = 9
    private static let headerBarHeight: CGFloat = 56
    private static let navButtonHorizontalInset: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)
    private static let checkboxSize: CGFloat = 16
    private static let horizontalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)
    private static let rowHeight: CGFloat = 60
    private static let sectionHeaderHeight: CGFloat = 32
    private static let sectionHeaderTopPadding: CGFloat = CGFloat(SpacingScheme.normalSpacing)
    private static let checkboxAvatarSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)
    private static let avatarTextSpacing: CGFloat = CGFloat(SpacingScheme.iconIconSpacing)
    private static let avatarSize: CGFloat = 40
    private static let indexBarEndPadding: CGFloat = CGFloat(SpacingScheme.smallSpacing)
    private static let indexBarVerticalPadding: CGFloat = CGFloat(SpacingScheme.bubbleSpacing)

    init(groupID: String, title: String, onConfirm: @escaping ([String]) -> Void) {
        self.pageTitle = title
        self.onConfirm = onConfirm
        self._viewModel = StateObject(wrappedValue: MentionMemberPickerViewModel(groupID: groupID))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ZStack {
                memberList
                if viewModel.isLoading && viewModel.members.isEmpty {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .onAppear {
            viewModel.loadMembers()
        }
    }

    private var headerBar: some View {
        ZStack {
            Text(pageTitle)
                .font(themeState.fonts.caption1Bold)
                .foregroundColor(themeState.colors.textColorPrimary)
                .lineLimit(1)
            HStack(spacing: 0) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text(LocalizedChatString("Cancel"))
                        .font(themeState.fonts.caption1Regular)
                        .foregroundColor(themeState.colors.textColorLink)
                }
                Spacer()
                Button(action: confirmSelection) {
                    Text(LocalizedChatString("Confirm"))
                        .font(themeState.fonts.caption1Regular)
                        .foregroundColor(selectedMembers.isEmpty ? themeState.colors.textColorTertiary : themeState.colors.textColorLink)
                }
                .disabled(selectedMembers.isEmpty)
            }
            .padding(.horizontal, Self.navButtonHorizontalInset)
        }
        .frame(height: Self.headerBarHeight)
        .frame(maxWidth: .infinity)
        .background(themeState.colors.bgColorOperate)
    }

    private func confirmSelection() {
        let userIDs = viewModel.members
            .filter { selectedMembers.contains($0.userID) }
            .map { $0.userID }
        guard !userIDs.isEmpty else { return }
        onConfirm(userIDs)
        presentationMode.wrappedValue.dismiss()
    }

    private var groupedMembers: [(letter: String, members: [GroupMember])] {
        let sorted = viewModel.members.sorted { a, b in
            pickerDisplayName(for: a).localizedCaseInsensitiveCompare(pickerDisplayName(for: b)) == .orderedAscending
        }
        var dict: [String: [GroupMember]] = [:]
        for member in sorted {
            dict[PinyinIndexHelper.sectionLetter(for: pickerDisplayName(for: member)), default: []].append(member)
        }
        let letters = dict.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }
        return letters.map { (letter: $0, members: dict[$0] ?? []) }
    }

    private var currentLetter: String? {
        visibleSectionLetter(
            atScrollOffset: sectionScrollOffset,
            orderedLetters: groupedMembers.map { $0.letter },
            sectionRowCounts: groupedMembers.map { $0.members.count }
        )
    }

    private var memberList: some View {
        let groups = groupedMembers
        let lastUserID = viewModel.members.last?.userID
        return ZStack(alignment: .trailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .scrollOffsetMarker(coordinateSpace: "GroupCallPickerScroll") { minY in
                                sectionScrollOffset = -minY
                            }
                        LazyVStack(spacing: 0) {
                            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                                VStack(spacing: 0) {
                                    sectionHeader(group.letter)
                                    ForEach(group.members, id: \.userID) { member in
                                        memberRow(member)
                                            .onAppear {
                                                if member.userID == lastUserID {
                                                    viewModel.loadMoreMembers()
                                                }
                                            }
                                    }
                                }
                                .id(group.letter)
                            }
                        }
                    }
                }
                .scrollDismissesKeyboardCompat()
                .coordinateSpace(name: "GroupCallPickerScroll")
                .onChange(of: scrollTarget) { target in
                    if let target = target {
                        proxy.scrollTo(target, anchor: .top)
                        scrollTarget = nil
                    }
                }
            }
            if !groups.isEmpty {
                LetterIndexBar(
                    sectionTitles: groups.map { $0.letter },
                    onLetterSelected: { scrollTarget = $0 },
                    scrubbingLetter: $scrubbingLetter,
                    currentLetter: currentLetter
                )
                .padding(.trailing, Self.indexBarEndPadding)
                .padding(.vertical, Self.indexBarVerticalPadding)
                .zIndex(1)
            }
            if let scrubbing = scrubbingLetter {
                LetterIndexCenterBubble(letter: scrubbing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(2)
            }
        }
    }

    private func sectionHeader(_ letter: String) -> some View {
        Text(letter)
            .font(themeState.fonts.caption2Bold)
            .foregroundColor(themeState.colors.textColorPrimary)
            .padding(.leading, Self.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.sectionHeaderHeight)
            .background(themeState.colors.bgColorDialog)
            .padding(.top, Self.sectionHeaderTopPadding)
    }

    private func memberRow(_ member: GroupMember) -> some View {
        let name = pickerDisplayName(for: member)
        return Button(action: { toggleSelection(member.userID) }) {
            HStack(spacing: 0) {
                SelectionCheckBox(isChecked: selectedMembers.contains(member.userID), size: Self.checkboxSize)
                    .padding(.trailing, Self.checkboxAvatarSpacing)
                AvatarView(url: member.avatarURL, name: name, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                    .frame(width: Self.avatarSize, height: Self.avatarSize)
                    .padding(.trailing, Self.avatarTextSpacing)
                Text(name)
                    .font(themeState.fonts.body4Regular)
                    .foregroundColor(themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.horizontalPadding)
            .frame(height: Self.rowHeight)
            .frame(maxWidth: .infinity)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func toggleSelection(_ userID: String) {
        if selectedMembers.contains(userID) {
            selectedMembers.remove(userID)
        } else if selectedMembers.count < Self.maxSelectableCount {
            selectedMembers.insert(userID)
        }
    }
}
