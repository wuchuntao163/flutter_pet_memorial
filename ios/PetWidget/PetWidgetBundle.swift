//
//  PetWidgetBundle.swift
//  PetWidget
//

import WidgetKit
import SwiftUI

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget {
        // WidgetBundleBuilder 不支持 if/else；部署目标已为 17.0，直接注册可配置组件
        ConfigurableHomeWidgetSmall()
        ConfigurableHomeWidgetMedium()
        PetLiveActivityWidget()
    }
}
