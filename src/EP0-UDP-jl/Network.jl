module Network


include("NetUtils.jl")
using .NetUtils

export bind_connections,
       Message,
       get_network_interface,
       get_flooding_interface
       # NetUtils

using Sockets
using ProgressMeter

include("Styles.jl")
include("Package.jl")
include("Utils.jl")
using .Package


mutable struct Message
    value :: Any
    destination_port :: Int64
end


bind_connections(rcv_buff::Channel, send_buff::Channel, net::Union{Interface,Nothing}=nothing) =
                bind_default_connections(rcv_buff, send_buff, net)

bind_connections(rcv_buff::Channel, net::Union{Interface,Nothing}=nothing) =
                bind_flood_connections(rcv_buff, net)


function bind_default_connections(rcv_buff::Channel, send_buff::Channel, net)
    @async begin
        try
            recv_msg(rcv_buff, net)
        catch
            show_stack_trace()
        end
    end


    @async begin
        try
            send_msg(send_buff, net)
        catch
            show_stack_trace()
        end
    end

end


function bind_flood_connections(rcv_buff::Channel, net)
    @async begin
        try
            recv_msg(rcv_buff, net)
        catch
            show_stack_trace()
        end
    end
end


function recv_msg(rcv_buff::Channel{Any}, net::Interface)
    datagrams_map = Dict{String, Array{Datagram}}()

    while true
        addr,package = recvfrom(net.socket)
        dg::Datagram = decode(package)

        msg_id = dg.msg_id
        if haskey(datagrams_map, msg_id) == false
            datagrams_map[msg_id] = [Datagram() for _ in 1:dg.total]
        end

        msg_seq = dg.sequence
        datagrams_map[msg_id][msg_seq] = dg

        if isempty(filter(x -> "-1" == x.msg_id, datagrams_map[msg_id]))
            msg = decode_msg(pop!(datagrams_map, msg_id))

            put!(rcv_buff, msg)
            msg = nothing
        end
    end
end



function send_msg(send_msg_buffer::Channel{Any}, net::Interface) ::Nothing
    # Send an string to who is listening on 'host' in 'port'
    socket = net.socket
    host = net.host

    while true
        msg = take!(send_msg_buffer)
        data_grams = encode_and_split(msg.value)

        total = length(data_grams)
        if total > 100
            println("Sending BIG msg, $(length(data_grams)) datagrams to send")
            p = Progress(total, barlen=20)

            for dg in data_grams
                next!(p); sleep(0.1)
                send(socket, host, msg.destination_port, dg)
            end
            finish!(p)
        else
            broadcast(x->send(socket, host, msg.destination_port, x), data_grams)
        end
        msg = nothing
        data_grams = nothing
    end
end



function get_network_interface() :: Interface
    socket = UDPSocket()

    host = Net_utils().host
    name,port = ("","")
    for a in Net_utils().port_queue
        name,port = a
        if bind(socket, host, port)
            println("$CGREEN Port $port in use by $name $CEND")
            return NetUtils.Interface(socket, port, host, name)
        end
    end
    error("$CRED2 Could not bind socket port $CEND")
end



"""
    get_flooding_interface(name)
    Args
    ----
    name: Just a nickname of the current peer

    Returns
    -------
    Interface struct containing some information about sending information
    through sockets

    Used to set an exclusive socket for receiving data from flooding.
"""
function get_flooding_interface(name::String) :: Interface
    socket = UDPSocket()
    host = Net_utils().host

    for port in 6666:7777
        if bind(socket, host, port)
            name = "$name@$host@$port"
            println("$CGREEN Port $port in use for recieving data from flooding $CEND")
            return Interface(socket, port, host, name)
        end
    end
    error("$CRED2 Could not bind server-socket port for flooding requests $CEND")
end



end # module
