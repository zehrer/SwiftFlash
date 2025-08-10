//
//  PartitionInfo.swift
//  SwiftFlash
//
//  Simple model describing a partition/slice of a disk (e.g. disk4s1).
//  This is transient discovery data; persistence is handled by higher-level models if needed.
//

import Foundation

struct PartitionInfo: Hashable, Identifiable {
    /// Stable identity: BSD name (e.g. "disk4s1") is unique per boot session
    var id: String { bsdName }

    /// BSD name (e.g. "disk4s1")
    let bsdName: String
    /// Absolute device node path (e.g. "/dev/disk4s1")
    let devicePath: String
    /// Partition size in bytes
    let size: Int64
    /// Volume name if available (DAVolumeName or DAMediaName)
    let volumeName: String?
    /// Filesystem/volume kind if available (e.g. "apfs", "msdos")
    let fileSystem: String?
    /// Mount point path if available
    let mountPoint: String?
    /// Whether the partition is writable (nil if unknown)
    let isWritable: Bool?
}


