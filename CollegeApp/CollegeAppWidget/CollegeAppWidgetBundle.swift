//
//  CollegeAppWidgetBundle.swift
//  CollegeAppWidget
//
//  Created by Wesley Wang on 2026/4/1.
//

import WidgetKit
import SwiftUI

@main
struct CollegeAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        CollegeAppWidget()
        CollegeAppWidgetControl()
        CollegeAppWidgetLiveActivity()
    }
}
