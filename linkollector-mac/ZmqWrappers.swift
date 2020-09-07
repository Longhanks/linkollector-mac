import Foundation

enum Activity: String {
    case URL = "URL"
    case Text = "TEXT"
}

let ActivityDelimiter = "\u{edfd}"

struct PollTarget {
    let socket: UnsafeMutableRawPointer
    let targetEvent: Int16
}

struct PollResponse {
    let responseSocket: UnsafeMutableRawPointer
    let responseEvent: Int16
}

typealias PThreadCallback = @convention(c) (UnsafeMutableRawPointer) -> UnsafeMutableRawPointer?

func blockingPoll(targets: [PollTarget]) -> [PollResponse]? {
    var zmqTargets = targets.map {
        zmq_pollitem_t(socket: $0.socket, fd: 0, events: $0.targetEvent, revents: 0)
    }

    let targetCount = Int32(zmqTargets.count)

    var response = [PollResponse]()

    let zmqRc = zmqTargets.withUnsafeMutableBufferPointer { targets in
        zmq_poll(targets.baseAddress, targetCount, /* timeout: */ -1)
    }

    if zmqRc == 0 {
        return response
    }

    if zmqRc == -1 {
        let errnum = errno
        if errnum == EINTR {
            return response
        }
        return nil
    }

    for i in 0..<zmqTargets.count {
        if zmqTargets[i].revents > 0 {
            if zmqTargets[i].revents & Int16(ZMQ_POLLIN) > 0 {
                response.append(PollResponse(responseSocket: targets[i].socket, responseEvent: Int16(ZMQ_POLLIN)))
            } else if zmqTargets[i].revents & Int16(ZMQ_POLLOUT) > 0 {
                response.append(PollResponse(responseSocket: targets[i].socket, responseEvent: Int16(ZMQ_POLLOUT)))
            }
        }
    }

    return response
}

func asyncReceive(socket: UnsafeMutableRawPointer, onMessage: (_ data: Data, _ didError: inout Bool) -> Void, didError: inout Bool) -> Bool {
    var msg = zmq_msg_t()
    zmq_msg_init(&msg)

    let zmqRc = zmq_msg_recv(&msg, socket, ZMQ_DONTWAIT)

    if zmqRc == 0 {
        // Success, but empty message
        onMessage(Data(), &didError)
        zmq_msg_close(&msg)
        return true
    }

    if zmqRc == -1 {
        zmq_msg_close(&msg)

        // If EAGAIN or EINTR, caller should try again
        return errno == EAGAIN || errno == EINTR
    }

    let data = Data(bytes: zmq_msg_data(&msg), count: zmq_msg_size(&msg))

    onMessage(data, &didError)
    zmq_msg_close(&msg)
    return true
}

func deserialize(_ data: Data) -> (Activity, String)? {
    let delimiter = ActivityDelimiter.data(using: .utf8)!
    let maybeDelimiterRange = data.range(of: delimiter)

    guard let delimiterRange = maybeDelimiterRange else {
        return nil
    }

    let maybeActivityString = String(data: data.subdata(in: data.startIndex..<delimiterRange.startIndex), encoding: .utf8)
    let maybeString = String(data: data.subdata(in: delimiterRange.endIndex..<data.endIndex), encoding: .utf8)

    guard let activityString = maybeActivityString, let activity = Activity(rawValue: activityString), let string = maybeString else {
        return nil
    }

    return (activity, string)
}
