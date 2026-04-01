//
//  CollegeAppWidgetBundle.swift
//  CollegeAppWidget
//
//  Created by 王耀偉 on 2026/4/1.
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
