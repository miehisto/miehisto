# frozen_string_literal: true

# mruby-simplehttpserver seems not supporting HTTP request body...

class SimpleHttpServer
  def request_to_env(io, req)
    req.headers.merge(
      Shelf::REQUEST_METHOD   => req.method,
      Shelf::PATH_INFO        => req.path || ROOT_PATH,
      Shelf::QUERY_STRING     => req.query,
      Shelf::HTTP_VERSION     => HTTP_VERSION,
      Shelf::SERVER_NAME      => 'mruby-simplehttpserver',
      Shelf::SERVER_ADDR      => host,
      Shelf::SERVER_PORT      => port,
      Shelf::SHELF_URL_SCHEME => req.schema,
      Shelf::SHELF_INPUT      => io,
      "_RAW_REQUEST"          => req
    )
  end
end

module Miehisto
  # Daemon: miehistod command entrypoint
  class HTTPApi
    def initialize(writers:, service_pid:)
      @writers = writers
      @service_pid = service_pid
    end

    def call(env)
      headers = {}
      headers['Content-type'] = 'application/json; charset=utf-8'
      code = 200
      body = ""

      begin
        path = env['PATH_INFO']
        case path
        when "/"
          body << {message: "This is our CREW!"}.to_json
        when "/v1/services/index"
          services = Service.list
          body << services.to_json
        when "/v1/services/create"
          params = json_body(env)
          s = Service.new(writer: @writers[:service], service_pid: @service_pid)
          s.create(**params)

          body << {
            pid: s.pid,
            args: s.args,
            object_id: s.object_id
          }.to_json
        when "/v1/services/delete"
          raise NotImplementedError
        when "/v1/services/dumps/create"
          params = json_body(env)
          if params
            d = Dumper.new(**params)
            d.dump
            body << {
              pid: d.pid,
              images_dir: d.images_dir
            }.to_json
          else
            code = 404
            body << {}.to_json
          end
        else
          code = 404
          body << {message: "Path #{path.inspect} is not registered"}.to_json
        end
      rescue Exception => err
        puts err.inspect
        puts err.backtrace.map{|v| "\t#{v}" }.join("\n")
        code = 503
        body << {
          message: "API error",
          err: err.inspect,
          path: path
        }.to_json
      end
      [code, headers, [body]]
    end

    def json_body(env)
      ret = {}
      if body = env['_RAW_REQUEST'].body
        b = JSON.parse(body)
        b.keys.each do |k|
          ret[k.to_sym] = b[k]
        end
        ret
      else
        nil
      end
    end
  end
end
