import Foundation

// Prepare query
let query = "kMDItemContentType === com.apple.disk-image-udif"
let searchQuery = MDQueryCreate(kCFAllocatorDefault, query as CFString, nil, nil)

// Run query
MDQueryExecute(searchQuery, CFOptionFlags(kMDQuerySynchronous.rawValue))
let resultCount = MDQueryGetResultCount(searchQuery)

// Prepare items
struct ScriptFilterItem: Codable {
  let variables: [String: Bool]
  let title: String
  let subtitle: String
  let type: String
  let icon: FileIcon
  let arg: String

  struct FileIcon: Codable {
    let path: String
    let type: String
  }
}

// Keep relevant results
let filteredMatches: [String] = (0..<resultCount).compactMap { resultIndex in
  let rawPointer = MDQueryGetResultAtIndex(searchQuery, resultIndex)
  let resultItem = Unmanaged<MDItem>.fromOpaque(rawPointer!).takeUnretainedValue()

  guard let resultPath = MDItemCopyAttribute(resultItem, kMDItemPath) as? String else { return nil }

  // Exclude results in ~/Library
  for libraryURL in FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask) {
    guard !resultPath.hasPrefix(libraryURL.path) else { return nil } }

  return resultPath
}

// No results
guard filteredMatches.count > 0 else {
  print(
    """
    {\"items\":[{\"title\":\"No Results\",
    \"subtitle\":\"No DMGs found\",
    \"valid\":false}]}
    """
  )

  exit(EXIT_SUCCESS)
}

// Items
let sfItems: [ScriptFilterItem] = filteredMatches.map { resultPath in
  let lastItem = filteredMatches.count == 1  // When trashing last item, hide Alfred

  return ScriptFilterItem(
    variables: ["last_item": lastItem],
    title: URL(fileURLWithPath: resultPath).lastPathComponent,
    subtitle: (resultPath as NSString).abbreviatingWithTildeInPath,
    type: "file",
    icon: ScriptFilterItem.FileIcon(path: resultPath, type: "fileicon"),
    arg: resultPath
  )
}

// Output JSON
let jsonData = try JSONEncoder().encode(["items": sfItems])
print(String(data: jsonData, encoding: .utf8)!)
