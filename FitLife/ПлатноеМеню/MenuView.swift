//
//  MenuView.swift
//  FitLife
//
//  Created by Виктор Корольков on 01.01.2025.
//

import SwiftUI

struct MenuView: View {
    var body: some View {
        ZStack {
            GradientView()
                .ignoresSafeArea()
            VStack {
                Text("Выберите")
                    .foregroundStyle(.white)
                    .font(.title)
                 //   .padding()
                Text("Программу питания")
                    .foregroundStyle(.white)
                    .font(.title)
                    .padding()
            //  Spacer()
                RoundedTextView(text: "1300 Ккалорий")
                RoundedTextView(text: "1700 Ккалорий")
                RoundedTextView(text: "2100 Ккалорий")
                Spacer()
            }
        }
    }
}
