//
// Copyright 2024 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation

public protocol PendingAttachment {
    var blurHash: String? { get }
    var sha256ContentHash: Data { get }
    var encryptedByteCount: UInt32 { get }
    var unencryptedByteCount: UInt32 { get }
    var mimeType: String { get }
    var encryptionKey: Data { get }
    var digestSHA256Ciphertext: Data { get }
    var localRelativeFilePath: String { get }
    var renderingFlag: AttachmentReference.RenderingFlag { get }
    var sourceFilename: String? { get }
    var validatedContentType: Attachment.ContentType { get }
    var orphanRecordId: OrphanedAttachmentRecord.IDType { get }
}

public enum ValidatedMessageBody {
    /// The original body was small enough to send as-is.
    case inline(MessageBody)
    /// The original body was too large; we truncated and created an attachment with the untruncated text.
    case oversize(truncated: MessageBody, fullsize: PendingAttachment)
}

public protocol AttachmentContentValidator {

    /// Validate and prepare a DataSource's contents, based on the provided mimetype.
    /// Returns a PendingAttachment with validated contents, ready to be inserted.
    /// Note the content type may be `invalid`; we can still create an Attachment from these.
    /// Errors are thrown if data reading/parsing fails.
    ///
    /// - Parameter  shouldConsume: If true, the source file will be deleted and the DataSource
    /// consumed after validation is complete; otherwise the source file will be left as-is.
    func validateContents(
        dataSource: DataSource,
        shouldConsume: Bool,
        mimeType: String,
        renderingFlag: AttachmentReference.RenderingFlag,
        sourceFilename: String?
    ) throws -> PendingAttachment

    /// Validate and prepare a Data's contents, based on the provided mimetype.
    /// Returns a PendingAttachment with validated contents, ready to be inserted.
    /// Note the content type may be `invalid`; we can still create an Attachment from these.
    /// Errors are thrown if data parsing fails.
    func validateContents(
        data: Data,
        mimeType: String,
        renderingFlag: AttachmentReference.RenderingFlag,
        sourceFilename: String?
    ) throws -> PendingAttachment

    /// Validate and prepare an encrypted attachment file's contents, based on the provided mimetype.
    /// Returns a PendingAttachment with validated contents, ready to be inserted.
    /// Note the content type may be `invalid`; we can still create an Attachment from these.
    /// Errors are thrown if data reading/parsing/decryption fails.
    ///
    /// - Parameter plaintextLength: If provided, the decrypted file will be truncated
    /// after this length. If nil, it is assumed the encrypted file has no custom padding (anything besides PKCS7)
    /// and will not be truncated after decrypting.
    func validateContents(
        ofEncryptedFileAt fileUrl: URL,
        encryptionKey: Data,
        plaintextLength: UInt32?,
        digestSHA256Ciphertext: Data,
        mimeType: String,
        renderingFlag: AttachmentReference.RenderingFlag,
        sourceFilename: String?
    ) throws -> PendingAttachment

    /// If the provided message body is large enough to require an oversize text
    /// attachment, creates a pending one, alongside the truncated message body.
    /// If not, just returns the message body as is.
    func prepareOversizeTextIfNeeded(
        from messageBody: MessageBody
    ) throws -> ValidatedMessageBody?

    /// Build a `QuotedReplyAttachmentDataSource` for a reply to a message with the provided attachment.
    /// Throws an error if the provided attachment is non-visual, or if data reading/writing fails.
    func prepareQuotedReplyThumbnail(
        fromOriginalAttachment: AttachmentStream,
        originalReference: AttachmentReference
    ) throws -> QuotedReplyAttachmentDataSource

    /// Build a `PendingAttachment` for a reply to a message with the provided attachment stream.
    /// Throws an error if the provided attachment is non-visual, or if data reading/writing fails.
    func prepareQuotedReplyThumbnail(
        fromOriginalAttachmentStream: AttachmentStream
    ) throws -> PendingAttachment
}

extension AttachmentContentValidator {

    public func validateContents(
        dataSource: DataSource,
        shouldConsume: Bool,
        mimeType: String,
        renderingFlag: AttachmentReference.RenderingFlag,
        sourceFilename: String?
    ) throws -> AttachmentDataSource {
        return .from(pendingAttachment: try self.validateContents(
            dataSource: dataSource,
            shouldConsume: shouldConsume,
            mimeType: mimeType,
            renderingFlag: renderingFlag,
            sourceFilename: sourceFilename
        ))
    }

    public func validateContents(
        data: Data,
        mimeType: String,
        renderingFlag: AttachmentReference.RenderingFlag,
        sourceFilename: String?
    ) throws -> AttachmentDataSource {
        return .from(pendingAttachment: try self.validateContents(
            data: data,
            mimeType: mimeType,
            renderingFlag: renderingFlag,
            sourceFilename: sourceFilename
        ))
    }

    public func validateContents(
        ofEncryptedFileAt fileUrl: URL,
        encryptionKey: Data,
        plaintextLength: UInt32,
        digestSHA256Ciphertext: Data,
        mimeType: String,
        renderingFlag: AttachmentReference.RenderingFlag,
        sourceFilename: String?
    ) throws -> AttachmentDataSource {
        return .from(pendingAttachment: try self.validateContents(
            ofEncryptedFileAt: fileUrl,
            encryptionKey: encryptionKey,
            plaintextLength: plaintextLength,
            digestSHA256Ciphertext: digestSHA256Ciphertext,
            mimeType: mimeType,
            renderingFlag: renderingFlag,
            sourceFilename: sourceFilename
        ))
    }
}
