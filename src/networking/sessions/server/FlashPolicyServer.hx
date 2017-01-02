package networking.sessions.server;

import haxe.io.Bytes;

import networking.sessions.server.Server;
import networking.sessions.server.Server.PortType;
import networking.utils.NetworkEvent;
import networking.utils.NetworkLogger;
import networking.wrappers.SocketWrapper;
import networking.wrappers.ThreadWrapper;

/**
 * Server for handling flash clients.
 *
 * Flash-based sockets for clients require a special server to manage policy restrictions,
 * on port 843 (default).
 *
 * For more information, please, check this article:
 *
 * http://www.adobe.com/devnet/flashplayer/articles/socket_policy_files.html
 *
 * This class is not intended to be handled manually.
 *
 * @author Daniel Herzog
 */
class FlashPolicyServer {
  public static var PORT: PortType = 9999;

  private var _port: PortType;

  private var _socket: SocketWrapper;
  private var _server: Server;

  private var _thread: ThreadWrapper;

  /**
   * TODO
   * @param server
   * @param port
   */
  public function new(server: Server, port: PortType = null) {
    if (port == null) port = PORT;

    _port = port;
    _server = server;

    _socket = new SocketWrapper();
  }

  /**
   * TODO
   */
  public function run() {
    #if !(cpp || neko)
    throw 'FlashPolicy Server is not available in non-native targets.';
    #end

    _thread = new ThreadWrapper(startServer, loopServer, stopServer);
  }

  /**
   * TODO
   */
  public function stop() {
    _thread.stop();
  }

  private function startServer() {
    try {
      _socket.bind(_server.ip, _port);
      _socket.listen(Server.MAX_LISTEN_INCOMING_REQUESTS);
    }
    catch (e: Dynamic) {
      _server.session().triggerEvent(NetworkEvent.SECURITY_ERROR, 'Could not start policy server.');
      return false;
    }
    trace("FPServer started!");

    return true;
  }

  private function loopServer(): Bool {
    var client: SocketWrapper;

    try {
      client = _socket.accept();
      if (client == null) return true;
    }
    catch (e: Dynamic) {
      return true;
    }

    var bytes: Bytes = Bytes.ofString(
      '<cross-domain-policy><site-control permitted-cross-domain-policies="all" /><allow-access-from domain="*" to-ports="*" /></cross-domain-policy>\x00'
    );

    try {
      client.writeBytes(bytes, bytes.length);
      client.close();
    }
    catch (e: Dynamic) {
      NetworkLogger.error(e);
    }

    return true;
  }

  private function stopServer() {
    _socket.close();
  }
}