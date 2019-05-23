import Foundation
#if os(macOS)
import SwiftSignalKitMac
import PostboxMac
#else
import SwiftSignalKit
import Postbox
#endif


public enum AvailableChannelDiscussionGroupError {
    case generic
}

public func availableGroupsForChannelDiscussion(network: Network) -> Signal<[Peer], AvailableChannelDiscussionGroupError> {
    return network.request(Api.functions.channels.getGroupsForDiscussion()) |> mapError { error in
        return .generic
    } |> map { result in
        let chats:[Api.Chat]
        switch result {
        case let .chats(c):
            chats = c
        case let .chatsSlice(_, c):
            chats = c
        }
        
        let peers = chats.compactMap {
            return parseTelegramGroupOrChannel(chat: $0)
        }
        
        return peers
    }
}

public func availableChannelsForGroupDiscussion(network: Network) -> Signal<[Peer], AvailableChannelDiscussionGroupError> {
    return network.request(Api.functions.channels.getBroadcastsForDiscussion()) |> mapError { _ in
        return .generic
        } |> map { result in
            let chats:[Api.Chat]
            switch result {
            case let .chats(c):
                chats = c
            case let .chatsSlice(_, c):
                chats = c
            }
            
            let peers = chats.compactMap {
                return parseTelegramGroupOrChannel(chat: $0)
            }
            
            return peers
    }
}

public enum ChannelDiscussionGroupError {
    case generic
}


//channels.setDiscussionGroup broadcast:InputChannel group:InputChannel = Bool;
public func updateGroupDiscussionForChannel(network: Network, postbox: Postbox, channelId: PeerId, groupId: PeerId) -> Signal<Bool, ChannelDiscussionGroupError> {
    
    return postbox.transaction { transaction -> (channel: Peer?, group: Peer?) in
        return (channel: transaction.getPeer(channelId), group: transaction.getPeer(groupId))
    }
    |> mapError { _ in ChannelDiscussionGroupError.generic }
    |> mapToSignal { peers -> Signal<Bool, ChannelDiscussionGroupError> in
        guard let channel = peers.channel, let group = peers.group else {
            return .fail(.generic)
        }
        guard let apiChannel = apiInputChannel(channel), let apiGroup = apiInputChannel(group) else {
            return .fail(.generic)
        }
        return network.request(Api.functions.channels.setDiscussionGroup(broadcast: apiChannel, group: apiGroup))
            |> mapError { error in
                return .generic
            }
            |> map { result in
                switch result {
                case .boolTrue:
                    return true
                case .boolFalse:
                    return false
                }
            }
    } |> mapToSignal { result in
        if result {
            return postbox.transaction { transaction in
                transaction.updatePeerCachedData(peerIds: Set([channelId]), update: { (_, current) -> CachedPeerData? in
                    return (current as? CachedChannelData ?? CachedChannelData()).withUpdatedAssociatedPeerId(groupId)
                })
            }
            |> introduceError(ChannelDiscussionGroupError.self)
            |> map { _ in
                return result
            }
        } else {
            return .single(result)
        }
    }
    
}
