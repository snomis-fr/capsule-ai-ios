//
//  TabRouter.swift
//  CapsuleAI
//
//  Navigation par onglets : une seule vue à la fois pour éviter les conflits WebView.
//

import SwiftUI

struct TabRouter: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch appState.selectedTabIndex {
                case 0:
                    HomeView()
                case 1:
                    SpacesView()
                case 2:
                    NavigationStack {
                        NoteEditorView(
                            mode: .create(subSpaceId: nil, spaceId: nil),
                            onSaveSuccess: { appState.selectedTabIndex = 0 },
                            onBack: { appState.selectedTabIndex = 0 }
                        )
                    }
                case 3:
                    SearchView()
                case 4:
                    ProfileView()
                default:
                    HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            customTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, icon: "square.grid.2x2", label: "Notes")
            tabButton(index: 1, icon: "folder.fill", label: "Espaces")
            tabButton(index: 2, icon: "plus.circle.fill", label: "Nouvelle note")
            tabButton(index: 3, icon: "magnifyingglass", label: "Recherche")
            tabButton(index: 4, icon: "person.circle.fill", label: "Profil")
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, 8)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func tabButton(index: Int, icon: String, label: String) -> some View {
        Button {
            appState.selectedTabIndex = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(appState.selectedTabIndex == index ? Color.capsulePrimary : Color(.secondaryLabel))
        }
        .buttonStyle(.plain)
    }
}
