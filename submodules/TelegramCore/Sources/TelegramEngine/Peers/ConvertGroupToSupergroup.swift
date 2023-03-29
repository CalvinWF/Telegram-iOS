import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum ConvertGroupToSupergroupError {
    case generic
    case tooManyChannels
}

func _internal_convertGroupToSupergroup(account: Account, peerId: PeerId, additionalProcessing: ((EnginePeer.Id) -> Signal<Never, NoError>)?) -> Signal<PeerId, ConvertGroupToSupergroupError> {
    return account.network.request(Api.functions.messages.migrateChat(chatId: peerId.id._internalGetInt64Value()))
    |> mapError { error -> ConvertGroupToSupergroupError in
        if error.errorDescription == "CHANNELS_TOO_MUCH" {
            return .tooManyChannels
        } else {
            return .generic
        }
    }
    |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
    |> mapToSignal { updates -> Signal<PeerId, ConvertGroupToSupergroupError> in
        var createdPeerId: PeerId?
        for message in updates.messages {
            if apiMessagePeerId(message) != peerId {
                createdPeerId = apiMessagePeerId(message)
                break
            }
        }
        
        if let createdPeerId = createdPeerId {
            let additionalProcessingValue: Signal<Never, NoError> = additionalProcessing?(createdPeerId) ?? Signal<Never, NoError>.complete()
            
            return additionalProcessingValue
            |> map { _ -> Bool in }
            |> castError(ConvertGroupToSupergroupError.self)
            |> then(Signal<Bool, ConvertGroupToSupergroupError>.single(true))
            |> mapToSignal { _ ->Signal<PeerId, ConvertGroupToSupergroupError> in
                account.stateManager.addUpdates(updates)
                
                return _internal_fetchAndUpdateCachedPeerData(accountPeerId: account.peerId, peerId: createdPeerId, network: account.network, postbox: account.postbox)
                |> castError(ConvertGroupToSupergroupError.self)
                |> mapToSignal { _ -> Signal<PeerId, ConvertGroupToSupergroupError> in
                    return account.postbox.multiplePeersView([createdPeerId])
                    |> filter { view in
                        return view.peers[createdPeerId] != nil
                    }
                    |> take(1)
                    |> map { _ in
                        return createdPeerId
                    }
                    |> mapError { _ -> ConvertGroupToSupergroupError in
                    }
                    |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
                }
            }
        } else {
            account.stateManager.addUpdates(updates)
            return .fail(.generic)
        }
    }
}

public enum ConvertGroupToGigagroupError {
    case generic
}

public func convertGroupToGigagroup(account: Account, peerId: PeerId) -> Signal<Never, ConvertGroupToGigagroupError> {
    return account.postbox.transaction { transaction -> Signal<Never, ConvertGroupToGigagroupError> in
        guard let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.channels.convertToGigagroup(channel: inputChannel))
        |> mapError { _ -> ConvertGroupToGigagroupError in return .generic }
        |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
        |> mapToSignal { updates -> Signal<Never, ConvertGroupToGigagroupError> in
            account.stateManager.addUpdates(updates)
            return .complete()
        }
    }
    |> mapError { _ -> ConvertGroupToGigagroupError in }
    |> switchToLatest
}
