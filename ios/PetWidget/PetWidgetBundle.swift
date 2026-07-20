//
//  PetWidgetBundle.swift
//  PetWidget
//

import WidgetKit
import SwiftUI

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget {
        // iOS 17+：系统长按「编辑小组件」可选「我的组件」
        if #available(iOSApplicationExtension 17.0, *) {
            ConfigurableHomeWidgetSmall()
            ConfigurableHomeWidgetMedium()
        } else {
            HomeScreenPetWidgetSmall()
            HomeScreenPetWidgetMedium()
        }
        if #available(iOS 16.2, *) {
            PetLiveActivityWidget()
        }
    }
}
