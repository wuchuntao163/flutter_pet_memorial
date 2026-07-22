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
        // 注意：WidgetBundleBuilder 不支持 if/else，白边在 View 层处理
        HomeScreenPetWidgetSmall()
        HomeScreenPetWidgetMedium()
        // Live Activity / Dynamic Island 仅 iOS 16.2+（仅 if、无 else，可编译）
        if #available(iOS 16.2, *) {
            PetLiveActivityWidget()
        }
    }
}
