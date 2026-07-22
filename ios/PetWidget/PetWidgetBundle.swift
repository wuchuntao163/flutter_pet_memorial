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
        // iOS 17+ 关闭系统 content margins，避免高版本白边；15.x 仍用原配置
        if #available(iOSApplicationExtension 17.0, *) {
            HomeScreenPetWidgetSmallNoMargins()
            HomeScreenPetWidgetMediumNoMargins()
        } else {
            HomeScreenPetWidgetSmall()
            HomeScreenPetWidgetMedium()
        }
        // Live Activity / Dynamic Island 仅 iOS 16.2+
        if #available(iOS 16.2, *) {
            PetLiveActivityWidget()
        }
    }
}
