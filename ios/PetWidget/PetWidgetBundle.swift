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
#if swift(>=5.9)
        // Live Activity 需 iOS 16.2+；仅在较新工具链注册
        PetLiveActivityWidget()
#endif
    }
}
