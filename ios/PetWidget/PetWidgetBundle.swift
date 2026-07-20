//
//  PetWidgetBundle.swift
//  PetWidget
//

import WidgetKit
import SwiftUI

@main
struct PetWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        HomeScreenPetWidget(
            kind: "PetWidgetSmall",
            displayName: "小号",
            family: .systemSmall
        )
        HomeScreenPetWidget(
            kind: "PetWidgetMedium",
            displayName: "中号",
            family: .systemMedium
        )
        if #available(iOS 16.2, *) {
            PetLiveActivityWidget()
        }
    }
}
