//
//  GradientView.swift
//  FitLife
//
//  Created by Виктор Корольков on 07.12.2024.
//

import SwiftUI

struct GradientView: View {
    var body: some View {
        LinearGradient(colors: [.blue ,
                                .blue .opacity(0.8),
                                .cyan ,
                                .cyan .opacity(0.5),
                                .cyan
                               ],
                       startPoint: .top,
                       endPoint: .bottom)
    }
}
#Preview {
    GradientView()
}
