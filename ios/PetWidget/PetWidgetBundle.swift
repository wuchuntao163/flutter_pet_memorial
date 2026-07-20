//
//  PetWidgetBundle.swift
//  PetWidget
//

import WidgetKit
import SwiftUI

@main
struct PetWidgetBundle: WidgetBundle {
    var body: some Widget {
        HomeScreenPetWidgetSmall()
        HomeScreenPetWidgetMedium()
        if #available(iOS 16.2, *) {
            PetLiveActivityWidget()
        }
    }
}
