//
//  PetWidgetBundle.swift
//  PetWidget
//

import WidgetKit
import SwiftUI

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget {
        // IntentConfiguration：添加后先显示引导，长按可「编辑小组件」
        HomeScreenPetWidgetSmall()
        HomeScreenPetWidgetMedium()
        // Live Activity / Dynamic Island 仅 iOS 16.2+
        if #available(iOS 16.2, *) {
            PetLiveActivityWidget()
        }
    }
}
