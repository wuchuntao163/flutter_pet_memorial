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
        if #available(iOS 17.0, *) {
            ConfigurableSavedWidget()
        } else {
            PetWidget()
        }
        if #available(iOS 16.2, *) {
            PetLiveActivityWidget()
        }
    }
}
