//
//  PetWidgetBundle.swift
//  PetWidget
//
//  Created by Mac on 2026/6/17.
//

import WidgetKit
import SwiftUI

@main
struct PetWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        PetWidget()
        if #available(iOS 16.2, *) {
            PetLiveActivityWidget()
        }
    }
}
