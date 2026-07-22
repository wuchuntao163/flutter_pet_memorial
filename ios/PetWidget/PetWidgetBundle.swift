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
        // 类型本身可在低部署目标编译；内部用 #available 区分 Live Activity
        PetLiveActivityWidget()
    }
}
