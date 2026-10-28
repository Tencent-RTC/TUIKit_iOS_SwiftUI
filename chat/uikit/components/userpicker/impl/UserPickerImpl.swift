import SwiftUI



struct UserPickerImpl: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeState: ThemeState
    @State private var selectedUsers: Set<String> = []
    @State private var selectedUsersOrder: [String] = []
    @State private var scrubbingLetter: String? = nil
    @State private var sectionScrollOffset: CGFloat = 0
    @State private var scrollTarget: String? = nil
    let userList: [UserPickerItem]
    let defaultSelectedItems: Set<String>
    let initialSelectedItems: Set<String>
    let showsChosenUsersHeader: Bool
    let maxCount: Int
    let onMaxCountExceed: (([UserPickerItem]) -> Void)?
    let onSelectedChanged: (([UserPickerItem]) -> Void)?
    let onLiveSelectionChanged: (([UserPickerItem]) -> Void)?
    let onReachEnd: (() -> Void)?
    let navigationTitle: String?
    let confirmTitle: String?
    let dismissOnConfirm: Bool

    init(
        userList: [UserPickerItem],
        defaultSelectedItems: Set<String> = [],
        initialSelectedItems: Set<String> = [],
        showsChosenUsersHeader: Bool = true,
        maxCount: Int = 1,
        navigationTitle: String? = nil,
        confirmTitle: String? = nil,
        dismissOnConfirm: Bool = true,
        onMaxCountExceed: (([UserPickerItem]) -> Void)? = nil,
        onSelectedChanged: (([UserPickerItem]) -> Void)?,
        onLiveSelectionChanged: (([UserPickerItem]) -> Void)? = nil,
        onReachEnd: (() -> Void)? = nil
    ) {
        self.userList = userList
        self.defaultSelectedItems = defaultSelectedItems
        self.initialSelectedItems = initialSelectedItems
        self.showsChosenUsersHeader = showsChosenUsersHeader
        self.maxCount = maxCount
        self.navigationTitle = navigationTitle
        self.confirmTitle = confirmTitle
        self.dismissOnConfirm = dismissOnConfirm
        self.onMaxCountExceed = onMaxCountExceed
        self.onSelectedChanged = onSelectedChanged
        self.onLiveSelectionChanged = onLiveSelectionChanged
        self.onReachEnd = onReachEnd
    }

    var body: some View {
        VStack(spacing: 0) {
            // 保留已选区域占位，避免选择变化时列表位置跳动。
            if showsChosenUsersHeader {
                chosenUsersHeader
                    .frame(height: selectedUsersList.isEmpty ? 0 : nil)
                    .opacity(selectedUsersList.isEmpty ? 0 : 1)
                    .clipped()
                    .animation(.easeInOut(duration: 0.2), value: selectedUsersList.isEmpty)
            }
            ZStack(alignment: .trailing) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: 0)
                                .scrollOffsetMarker(coordinateSpace: "UserPickerScroll") { minY in
                                    sectionScrollOffset = -minY
                                }
                            LazyVStack(spacing: 0) {
                                ForEach(Array(groupedUsers.enumerated()), id: \.offset) { _, group in
                                    // 分组 ID 须位于 ForEach 直接子视图，确保离屏分组可定位。
                                    VStack(spacing: 0) {
                                        sectionHeader(group.letter)
                                        ForEach(group.users, id: \.userID) { user in
                                            userRow(user)
                                        }
                                    }
                                    .id(group.letter)
                                }
                            }
                        }
                    }
                    .onChange(of: scrollTarget) { target in
                        if let target = target {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                            scrollTarget = nil
                        }
                    }
                    .coordinateSpace(name: "UserPickerScroll")
                }
                if !groupedUsers.isEmpty {
                    LetterIndexBar(
                        sectionTitles: groupedUsers.map { $0.letter },
                        onLetterSelected: { scrollTarget = $0 },
                        scrubbingLetter: $scrubbingLetter,
                        currentLetter: currentLetter
                    )
                    .padding(.trailing, CGFloat(SpacingScheme.iconTextSpacing))
                    .zIndex(1)
                }
                if let scrubbing = scrubbingLetter {
                    LetterIndexCenterBubble(letter: scrubbing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .zIndex(2)
                }
            }
        }
        .navigationBarTitle(navigationTitle ?? LocalizedChatString("ChooseUser"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(LocalizedChatString("Cancel")) {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(themeState.colors.textColorLink),
            trailing: Button(confirmTitle ?? LocalizedChatString("Done")) {
                onSelectedChanged?(selectedUsersList)
                if dismissOnConfirm {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .foregroundColor(selectedUsersList.isEmpty ? themeState.colors.textColorDisable : themeState.colors.textColorLink)
            .disabled(selectedUsersList.isEmpty)
        )
        .onAppear {
            guard selectedUsers.isEmpty, selectedUsersOrder.isEmpty else { return }
            let editable = initialSelectedItems.subtracting(defaultSelectedItems)
            selectedUsers = editable
            selectedUsersOrder = userList.map(\.userID).filter { editable.contains($0) }
        }
    }

    @ViewBuilder
    private var chosenUsersHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedChatString("Chosen") + "\(selectedUsersList.count) " + LocalizedChatString("People"))
                    .font(FontScheme.caption3Regular)
                    .foregroundColor(themeState.colors.textColorSecondary)
                Spacer()
            }
            .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            .padding(.top, CGFloat(SpacingScheme.iconIconSpacing))
            .padding(.bottom, CGFloat(SpacingScheme.smallSpacing))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                    ForEach(selectedUsersList, id: \.userID) { user in
                        VStack(spacing: CGFloat(SpacingScheme.iconTextSpacing)) {
                            AvatarView(
                                url: user.avatarURL,
                                name: user.title,
                                size: .l
                            )
                            Text(user.title)
                                .font(FontScheme.caption3Regular)
                                .foregroundColor(themeState.colors.textColorPrimary)
                                .lineLimit(1)
                                .frame(width: 50)
                        }
                    }
                }
                .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
            }
            .padding(.bottom, CGFloat(SpacingScheme.iconIconSpacing))
            Divider()
        }
        .background(themeState.colors.bgColorOperate.opacity(0.05))
    }

    private var selectedUsersList: [UserPickerItem] {
        var orderedUsers: [UserPickerItem] = []
        for userID in selectedUsersOrder {
            if let user = userList.first(where: { $0.userID == userID }) {
                orderedUsers.append(user)
            }
        }
        return orderedUsers
    }


    private var groupedUsers: [(letter: String, users: [UserPickerItem])] {
        let sorted = userList.sorted { a, b in
            displayTitle(a).localizedCaseInsensitiveCompare(displayTitle(b)) == .orderedAscending
        }
        var dict: [String: [UserPickerItem]] = [:]
        for user in sorted {
            let letter = PinyinIndexHelper.sectionLetter(for: displayTitle(user))
            dict[letter, default: []].append(user)
        }
        let sortedLetters = dict.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }
        return sortedLetters.map { (letter: $0, users: dict[$0] ?? []) }
    }

    private var currentLetter: String? {
        visibleSectionLetter(
            atScrollOffset: sectionScrollOffset,
            orderedLetters: groupedUsers.map { $0.letter },
            sectionRowCounts: groupedUsers.map { $0.users.count }
        )
    }

    private func displayTitle(_ user: UserPickerItem) -> String {
        user.title.isEmpty ? user.userID : user.title
    }

    private func sectionHeader(_ letter: String) -> some View {
        HStack {
            Text(letter)
                .font(themeState.fonts.caption2Bold)
                .foregroundColor(themeState.colors.textColorPrimary)
            Spacer()
        }
        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
        .frame(height: 32)
        .background(themeState.colors.bgColorDialog)
    }

    private func userRow(_ user: UserPickerItem) -> some View {
        UserPickerRow(
            user: user,
            isSelected: selectedUsers.contains(user.userID) || defaultSelectedItems.contains(user.userID),
            isPreSelected: defaultSelectedItems.contains(user.userID),
            onToggle: { isSelected in
                toggleUser(user, isSelected: isSelected)
            }
        )
    }

    private func toggleUser(_ user: UserPickerItem, isSelected: Bool) {
        if defaultSelectedItems.contains(user.userID) {
            return
        }
        if maxCount == 1 {
            if isSelected {
                selectedUsers = [user.userID]
                selectedUsersOrder = [user.userID]
            } else {
                selectedUsers.removeAll()
                selectedUsersOrder.removeAll()
            }
        } else {
            if isSelected {
                if maxCount > 1, selectedUsers.count >= maxCount { return }
                selectedUsers.insert(user.userID)
                selectedUsersOrder.append(user.userID)
            } else {
                selectedUsers.remove(user.userID)
                selectedUsersOrder.removeAll { $0 == user.userID }
            }
        }
        onLiveSelectionChanged?(selectedUsersList)
    }
}

struct UserPickerRow: View {
    @EnvironmentObject var themeState: ThemeState
    let user: UserPickerItem
    let isSelected: Bool
    let isPreSelected: Bool
    let onToggle: (Bool) -> Void

    private static let rowHeight: CGFloat = 60
    private static let checkboxAvatarSpacing = CGFloat(SpacingScheme.smallSpacing)
    private static let avatarTextSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let horizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)

    var body: some View {
        let isLocked = user.isDisabled || isPreSelected
        Button(action: {
            onToggle(!isSelected)
        }) {
            HStack(spacing: 0) {
                SelectionCheckBox(isChecked: isSelected, isLocked: isLocked)
                AvatarView(url: user.avatarURL, name: user.title, size: .m, shape: .roundedRectangle)
                    .padding(.leading, Self.checkboxAvatarSpacing)
                Text(user.title)
                    .font(themeState.fonts.body4Regular)
                    .foregroundColor(isLocked ? themeState.colors.textColorSecondary : themeState.colors.textColorPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, Self.avatarTextSpacing)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.horizontalPadding)
            .frame(height: Self.rowHeight)
            .frame(maxWidth: .infinity)
            .background(themeState.colors.bgColorOperate)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLocked)
    }
}


struct CreateGroupMemberPickerView: View {
    @EnvironmentObject var themeState: ThemeState
    let userList: [UserPickerItem]
    let onGroupCreated: (String?, String?, String?) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var selectedIDs: Set<String> = []
    @State private var selectedOrder: [String] = []
    @State private var configMembers: [UserPickerItem]? = nil
    @State private var scrubbingLetter: String? = nil
    @State private var sectionScrollOffset: CGFloat = 0
    @State private var scrollTarget: String? = nil
    @FocusState private var searchFocused: Bool

    private static let rowHeight: CGFloat = 60
    private static let sectionHeaderHeight: CGFloat = 32
    private static let horizontalPadding = CGFloat(SpacingScheme.bubbleSpacing)
    private static let checkboxSize: CGFloat = 16
    private static let checkboxAvatarSpacing = CGFloat(SpacingScheme.smallSpacing)
    private static let avatarTextSpacing = CGFloat(SpacingScheme.iconIconSpacing)
    private static let confirmButtonHeight: CGFloat = 36
    private static let confirmButtonCornerRadius = CGFloat(RadiusScheme.tipsRadius)
    private static let bottomBarVerticalPadding = CGFloat(SpacingScheme.smallSpacing)

    private var filteredList: [UserPickerItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces)
        if keyword.isEmpty { return userList }
        return userList.filter {
            $0.title.range(of: keyword, options: .caseInsensitive) != nil
                || $0.userID.range(of: keyword, options: .caseInsensitive) != nil
        }
    }

    private var groupedUsers: [(letter: String, users: [UserPickerItem])] {
        let sorted = filteredList.sorted { a, b in
            displayTitle(a).localizedCaseInsensitiveCompare(displayTitle(b)) == .orderedAscending
        }
        var dict: [String: [UserPickerItem]] = [:]
        for user in sorted {
            let letter = PinyinIndexHelper.sectionLetter(for: displayTitle(user))
            dict[letter, default: []].append(user)
        }
        let sortedLetters = dict.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }
        return sortedLetters.map { (letter: $0, users: dict[$0] ?? []) }
    }

    private var currentLetter: String? {
        visibleSectionLetter(
            atScrollOffset: sectionScrollOffset,
            orderedLetters: groupedUsers.map { $0.letter },
            sectionRowCounts: groupedUsers.map { $0.users.count }
        )
    }

    private var selectedList: [UserPickerItem] {
        selectedOrder.compactMap { id in userList.first(where: { $0.userID == id }) }
    }

    private func displayTitle(_ user: UserPickerItem) -> String {
        user.title.isEmpty ? user.userID : user.title
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            pickerList
            bottomBar
        }
        .background(themeState.colors.bgColorOperate.ignoresSafeArea())
        .navigationBarTitle(LocalizedChatString("CreateGroupTitle"), displayMode: .inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: NavBackButtonView(action: onCancel))
        .background(
            NavigationLink(
                destination: GroupConfigPushHost(members: configMembers ?? [], onGroupCreated: onGroupCreated),
                isActive: Binding(
                    get: { configMembers != nil },
                    set: { if !$0 { configMembers = nil } }
                )
            ) { EmptyView() }
            .hidden()
        )
    }

    private struct GroupConfigPushHost: View {
        @EnvironmentObject var themeState: ThemeState
        let members: [UserPickerItem]
        let onGroupCreated: (String?, String?, String?) -> Void
        @Environment(\.presentationMode) var presentationMode

        var body: some View {
            ConfigGroupInfoView(
                members: members,
                onComplete: { gid, name, cid in
                    onGroupCreated(gid, name, cid)
                },
                onBack: {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .environmentObject(themeState)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 0) {
            Image("contact_search", bundle: AtomicXChatResources.resourceBundle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 15, height: 15)
                .foregroundColor(themeState.colors.textColorTertiary)
                .padding(.leading, CGFloat(SpacingScheme.smallSpacing))
            TextField("", text: $searchText)
                .font(themeState.fonts.caption2Regular)
                .foregroundColor(themeState.colors.textColorPrimary)
                .placeholder(when: searchText.isEmpty, hint: LocalizedChatString("Search"), color: themeState.colors.textColorTertiary, alignment: .leading)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($searchFocused)
                .padding(.horizontal, CGFloat(SpacingScheme.smallSpacing))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image("contact_search_clear", bundle: AtomicXChatResources.resourceBundle)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .foregroundColor(themeState.colors.textColorPrimary)
                }
                .padding(.trailing, CGFloat(SpacingScheme.iconIconSpacing))
            }
        }
        .frame(height: 36)
        .background(themeState.colors.bgColorInput)
        .cornerRadius(CGFloat(RadiusScheme.alertRadius))
        .padding(CGFloat(SpacingScheme.bubbleSpacing))
        .background(themeState.colors.bgColorOperate)
    }

    private var pickerList: some View {
        ZStack(alignment: .trailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .scrollOffsetMarker(coordinateSpace: "CreateGroupPickerScroll") { minY in
                                sectionScrollOffset = -minY
                            }
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            ForEach(Array(groupedUsers.enumerated()), id: \.offset) { _, group in
                                // 分组 ID 须位于 ForEach 直接子视图，确保离屏分组可定位。
                                VStack(spacing: 0) {
                                    sectionHeader(group.letter)
                                    ForEach(group.users, id: \.userID) { user in
                                        pickerRow(user)
                                    }
                                }
                                .id(group.letter)
                            }
                        }
                    }
                }
                .scrollDismissesKeyboardCompat()
                .coordinateSpace(name: "CreateGroupPickerScroll")
                .onChange(of: scrollTarget) { target in
                    if let target = target {
                        proxy.scrollTo(target, anchor: .top)
                        scrollTarget = nil
                    }
                }
            }
            if !groupedUsers.isEmpty {
                LetterIndexBar(sectionTitles: groupedUsers.map { $0.letter }, onLetterSelected: { scrollTarget = $0 }, scrubbingLetter: $scrubbingLetter, currentLetter: currentLetter)
                    .padding(.trailing, CGFloat(SpacingScheme.smallSpacing))
                    .padding(.vertical, CGFloat(SpacingScheme.bubbleSpacing))
                    .zIndex(1)
            }
            if let scrubbing = scrubbingLetter {
                LetterIndexCenterBubble(letter: scrubbing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sectionHeader(_ letter: String) -> some View {
        HStack {
            Text(letter)
                .font(themeState.fonts.caption2Bold)
                .foregroundColor(themeState.colors.textColorPrimary)
            Spacer()
        }
        .padding(.horizontal, Self.horizontalPadding)
        .frame(height: Self.sectionHeaderHeight)
        .frame(maxWidth: .infinity)
        .background(themeState.colors.bgColorDialog)
        .padding(.top, 22)
    }

    private func pickerRow(_ user: UserPickerItem) -> some View {
        let isSelected = selectedIDs.contains(user.userID)
        let isLocked = user.isDisabled
        return Button(action: {
            searchFocused = false
            toggle(user)
        }) {
            HStack(spacing: 0) {
                SelectionCheckBox(isChecked: isSelected, isLocked: isLocked, size: Self.checkboxSize)
                    .padding(.trailing, Self.checkboxAvatarSpacing)
                AvatarView(url: user.avatarURL ?? "", name: user.title, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                    .frame(width: 40, height: 40)
                    .padding(.trailing, Self.avatarTextSpacing)
                Text(user.title)
                    .font(themeState.fonts.body4Regular)
                    .foregroundColor(isLocked ? themeState.colors.textColorSecondary : themeState.colors.textColorPrimary)
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
        .disabled(isLocked)
    }

    private func toggle(_ user: UserPickerItem) {
        guard !user.isDisabled else { return }
        if selectedIDs.contains(user.userID) {
            selectedIDs.remove(user.userID)
            selectedOrder.removeAll { $0 == user.userID }
        } else {
            selectedIDs.insert(user.userID)
            selectedOrder.append(user.userID)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(themeState.colors.strokeColorSecondary)
                .frame(height: 0.5)
            HStack(spacing: CGFloat(SpacingScheme.iconIconSpacing)) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CGFloat(SpacingScheme.smallSpacing)) {
                            ForEach(Array(selectedList.enumerated()), id: \.offset) { index, item in
                                AvatarView(url: item.avatarURL ?? "", name: item.title, shape: .roundedRectangle, cornerRadius: CGFloat(RadiusScheme.tipsRadius))
                                    .frame(width: 40, height: 40)
                                    .id(index)
                            }
                        }
                        .padding(.leading, CGFloat(SpacingScheme.bubbleSpacing))
                    }
                    .onChange(of: selectedList.count) { _ in
                        if let last = selectedList.indices.last {
                            proxy.scrollTo(last, anchor: .trailing)
                        }
                    }
                }
                Button(action: {
                    guard !selectedList.isEmpty else { return }
                    configMembers = selectedList
                }) {
                    Text(String(format: LocalizedChatString("ConfirmSelectionFormat"), selectedList.count))
                        .font(themeState.fonts.caption2Bold)
                        .foregroundColor(themeState.colors.textColorButton)
                        .padding(.horizontal, CGFloat(SpacingScheme.bubbleSpacing))
                        .frame(height: Self.confirmButtonHeight)
                        .background(selectedList.isEmpty ? themeState.colors.textColorDisable : themeState.colors.textColorLink)
                        .cornerRadius(Self.confirmButtonCornerRadius)
                }
                .disabled(selectedList.isEmpty)
                .padding(.trailing, CGFloat(SpacingScheme.bubbleSpacing))
            }
            .padding(.vertical, Self.bottomBarVerticalPadding)
        }
        .background(themeState.colors.bgColorOperate)
    }
}
