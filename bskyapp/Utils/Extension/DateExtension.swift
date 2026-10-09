//
//  DateExtension.swift
//  bskyapp
//
//  Created by shuya on 2024/05/30.
//

import Foundation

extension Date {
    var relativeDateString: String{
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        guard let date = formatter.string(for: self) else{
            return "invalid"
        }
        return date
    }
}
