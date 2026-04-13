import SwiftUI

struct LinkCardView: View {
    var externalLink: EmbeddedExternalViewItem?
    var uri: String?
    
    init(externalLink: EmbeddedExternalViewItem) {
        self.externalLink = externalLink
        self.uri = nil
    }
    
    init(uri: String) {
        self.externalLink = nil
        self.uri = uri
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let externalLink = externalLink {
                // 外部リンク情報がある場合はそれを表示
                LinkCardContentView(
                    title: externalLink.title,
                    description: externalLink.description,
                    uri: externalLink.uri,
                    thumbUrl: externalLink.thumb != nil ? URL(string: externalLink.thumb!) : nil
                )
            } else if let uri = uri {
                // URIのみの場合はシンプルなリンクカードを表示
                LinkCardContentView(
                    title: getHostFromUri(uri),
                    description: "",
                    uri: uri,
                    thumbUrl: nil
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getHostFromUri(_ uriString: String) -> String {
        guard let url = URL(string: uriString),
              let host = url.host else {
            return uriString
        }
        return host
    }
}

struct LinkCardContentView: View {
    let title: String
    let description: String
    let uri: String
    let thumbUrl: URL?
    
    var body: some View {
        Link(destination: URL(string: uri) ?? URL(string: "https://example.com")!) {
            HStack(alignment: .top, spacing: 12) {
                if let thumbUrl = thumbUrl {
                    AsyncImageView(viewModel: AsyncImageViewModel(
                        url: thumbUrl,
                        imageSize: .thumbnail,
                        alt: title
                    ))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    if !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .lineLimit(3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(getDisplayUri(uri))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private func getDisplayUri(_ uriString: String) -> String {
        guard let url = URL(string: uriString) else {
            return uriString
        }
        
        var displayString = url.host ?? ""
        let path = url.path
            displayString += path
        
        return displayString
    }
}

#Preview {
    VStack(spacing: 20) {
        LinkCardView(externalLink: EmbeddedExternalViewItem(
            uri: "https://example.com",
            title: "Example Website",
            description: "This is an example website description that might be a bit longer to show how it wraps.",
            thumb: nil
        ))
        
        LinkCardView(uri: "https://github.com/akagisrapid/rapipopo")
    }
    .padding()
}
