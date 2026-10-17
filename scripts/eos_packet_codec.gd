class_name EosPacketCodec
extends RefCounted

const CHUNK=800
const HEADER=48
const MAX_BYTES=262144
const MAX_INFLIGHT=4
var pending: Dictionary={}
var rejected: int=0

static func digest_bytes(bytes: PackedByteArray) -> PackedByteArray:
    var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish()

static func encode(bytes: PackedByteArray,sequence: int) -> Array[PackedByteArray]:
    var frames: Array[PackedByteArray]=[]
    if bytes.is_empty() or bytes.size()>MAX_BYTES:return frames
    var count: int=ceili(float(bytes.size())/CHUNK)
    var digest: PackedByteArray=digest_bytes(bytes)
    for i in range(count):
        var frame=PackedByteArray();frame.resize(HEADER)
        frame.encode_u32(0,0x53434531);frame.encode_u32(4,sequence)
        frame.encode_u16(8,i);frame.encode_u16(10,count);frame.encode_u32(12,bytes.size())
        for j in range(32):frame[16+j]=digest[j]
        frame.append_array(bytes.slice(i*CHUNK,mini(bytes.size(),(i+1)*CHUNK)));frames.append(frame)
    return frames

func consume(sender: int,frame: PackedByteArray,now: int) -> PackedByteArray:
    expire(now)
    if frame.size()<=HEADER or frame.size()>HEADER+CHUNK or frame.decode_u32(0)!=0x53434531:rejected+=1;return PackedByteArray()
    var seq: int=frame.decode_u32(4);var index: int=frame.decode_u16(8);var count: int=frame.decode_u16(10);var total: int=frame.decode_u32(12)
    if total<=0 or total>MAX_BYTES or count!=ceili(float(total)/CHUNK) or index>=count:rejected+=1;return PackedByteArray()
    var expected: int=mini(CHUNK,total-index*CHUNK)
    if frame.size()!=HEADER+expected:rejected+=1;return PackedByteArray()
    var key: String=str(sender)+":"+str(seq);var digest: PackedByteArray=frame.slice(16,48)
    if not pending.has(key):
        if pending.size()>=MAX_INFLIGHT:rejected+=1;return PackedByteArray()
        pending[key]={"count":count,"total":total,"hash":digest,"chunks":{},"until":now+15000}
    var message: Dictionary=pending[key]
    if count!=message.count or total!=message.total or digest!=message.hash:pending.erase(key);rejected+=1;return PackedByteArray()
    message.chunks[index]=frame.slice(HEADER)
    if message.chunks.size()!=count:return PackedByteArray()
    var bytes=PackedByteArray()
    for i in range(count):bytes.append_array(message.chunks[i])
    pending.erase(key)
    if digest_bytes(bytes)!=digest:rejected+=1;return PackedByteArray()
    return bytes

func expire(now: int) -> void:
    for key in pending.keys():
        if now>int(pending[key].until):pending.erase(key)
