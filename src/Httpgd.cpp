
#include <cpp11/function.hpp>
#include <cpp11/strings.hpp>
#include <cpp11/list.hpp>
#include <cpp11/integers.hpp>
#include <cpp11/as.hpp>
#include <cpp11/raws.hpp>

//#include <R_ext/GraphicsEngine.h>

#include <vector>
#include <string>

#include "HttpgdDev.h"
#include "RendererSvg.h"
#include "RendererManager.h"

namespace httpgd
{

    // returns system path to {package}/inst/www/{filename}
    std::string get_wwwpath(const std::string &filename)
    {
        using namespace cpp11::literals;

        auto sys_file = cpp11::package("base")["system.file"];

        cpp11::strings res(sys_file("www", filename,
                                          "package"_nm = "httpgd"));
        return res[0];
    }

    inline HttpgdDev *getDev(pDevDesc dd)
    {
        return static_cast<HttpgdDev *>(dd->deviceSpecific);
    }

    // --------------------------------------

} // namespace httpgd

[[cpp11::register]]
bool httpgd_(std::string host, int port, std::string bg, double width, double height,
             double pointsize, cpp11::list aliases, bool cors, std::string token, bool webserver, bool silent, bool fix_text_width, std::string extra_css)
{
    bool recording = true;
    bool use_token = token.length();
    int ibg = R_GE_str2col(bg.c_str());

    std::string wwwpath(httpgd::get_wwwpath(""));

    boost::optional<std::string> css;
    if (!extra_css.empty()) 
    {
        css = extra_css;
    }

    auto dev = new httpgd::HttpgdDev(
        {std::move(host),
         port,
         wwwpath,
         cors,
         use_token,
         token,
         recording,
         webserver,
         silent},
        {ibg,
         width,
         height,
         pointsize,
         aliases,
         fix_text_width,
         css});

    httpgd::HttpgdDev::make_device("httpgd", dev);
    return dev->server_start();
}

inline httpgd::HttpgdDev *validate_httpgddev(int devnum)
{
    if (devnum < 1 || devnum > 64) // R_MaxDevices
    {
        cpp11::stop("invalid graphical device number");
    }

    pGEDevDesc gdd = GEgetDevice(devnum - 1);
    if (!gdd)
    {
        cpp11::stop("invalid device");
    }
    pDevDesc dd = gdd->dev;
    if (!dd)
    {
        cpp11::stop("invalid device");
    }
    auto dev = static_cast<httpgd::HttpgdDev *>(dd->deviceSpecific);
    if (!dev)
    {
        cpp11::stop("invalid device");
    }

    return dev;
}

inline long validate_plotid(const std::string &id)
{
    try {
        return std::stol(id);
    }
    catch (const std::exception &e){
        cpp11::stop("Not a valid plot ID.");
    }
    return -1;
}

[[cpp11::register]]
cpp11::list httpgd_state_(int devnum)
{
    auto dev = validate_httpgddev(devnum);

    auto svr_config = dev->api_server_config();
    httpgd::HttpgdState state = dev->api_state();

    using namespace cpp11::literals;
    return cpp11::writable::list{
        "host"_nm = svr_config->host.c_str(),
        "port"_nm = dev->server_port(),
        "token"_nm = svr_config->token.c_str(),
        "hsize"_nm = state.hsize,
        "upid"_nm = state.upid,
        "active"_nm = state.active};
}

[[cpp11::register]]
cpp11::list httpgd_renderers_(int devnum)
{
    
    using namespace cpp11::literals;

    const auto &renderers = httpgd::RendererManager::defaults();

    cpp11::writable::list rens{static_cast<R_xlen_t>(renderers.size())};

    R_xlen_t i = 0;
    for (auto it = renderers.string_renderers().begin(); it != renderers.string_renderers().end(); it++) 
    {
        rens[i++] = cpp11::writable::list{
                "id"_nm = it->second.id,
                "mime"_nm = it->second.mime,
                "ext"_nm = it->second.fileext,
                "name"_nm = it->second.name,
                "type"_nm = it->second.type,
                "bin"_nm = false};
    }
    for (auto it = renderers.binary_renderers().begin(); it != renderers.binary_renderers().end(); it++) 
    {
        rens[i++] = cpp11::writable::list{
                "id"_nm = it->second.id,
                "mime"_nm = it->second.mime,
                "ext"_nm = it->second.fileext,
                "name"_nm = it->second.name,
                "type"_nm = it->second.type,
                "bin"_nm = true};
    }

    return rens;
}

[[cpp11::register]]
std::string httpgd_random_token_(int len)
{
    if (len < 0)
    {
        cpp11::stop("Length needs to be 0 or higher.");
    }
    return httpgd::HttpgdDev::random_token(len);
}

[[cpp11::register]]
bool httpgd_renderer_is_str_(std::string renderer_id)
{
    return httpgd::RendererManager::defaults().find_string(renderer_id) ? true : false;
}
[[cpp11::register]]
bool httpgd_renderer_is_raw_(std::string renderer_id)
{
    return httpgd::RendererManager::defaults().find_binary(renderer_id) ? true : false;
}

[[cpp11::register]]
int httpgd_plot_find_(int devnum, std::string plot_id)
{
    long pid = validate_plotid(plot_id);
    auto dev = validate_httpgddev(devnum);
    auto page = dev->api_index(pid);
    if (!page)
    {
        cpp11::stop("Not a valid plot ID.");
    }
    return *page;
}

[[cpp11::register]]
std::string httpgd_plot_str_(int devnum, int page, double width, double height, double zoom, std::string renderer_id)
{
    auto dev = validate_httpgddev(devnum);

    if (width < 0 || height < 0)
    {
        zoom = 1;
    }

    auto fi_renderer = httpgd::RendererManager::defaults().find_string(renderer_id);
    if (!fi_renderer)
    {
        cpp11::stop("Not a valid string renderer ID.");
    }
    auto renderer = (*fi_renderer).renderer();
    dev->api_render(page, width / zoom, height / zoom, renderer.get(), zoom);
    return renderer->get_string();
}

[[cpp11::register]]
cpp11::raws httpgd_plot_raw_(int devnum, int page, double width, double height, double zoom, std::string renderer_id)
{
    auto dev = validate_httpgddev(devnum);

    if (width < 0 || height < 0)
    {
        zoom = 1;
    }

    auto fi_renderer = httpgd::RendererManager::defaults().find_binary(renderer_id);
    if (!fi_renderer)
    {
        cpp11::stop("Not a valid binary renderer ID.");
    }
    auto renderer = (*fi_renderer).renderer();
    dev->api_render(page, width / zoom, height / zoom, renderer.get(), zoom);

    auto bin = renderer->get_binary();
    cpp11::writable::raws raw(bin.begin(), bin.end());
    return raw;
}

[[cpp11::register]]
bool httpgd_remove_(int devnum, int page)
{
    auto dev = validate_httpgddev(devnum);
    return dev->api_remove(page);
}

[[cpp11::register]]
bool httpgd_remove_id_(int devnum, std::string id)
{
    long pid = validate_plotid(id);
    auto dev = validate_httpgddev(devnum);
    auto page = dev->api_index(pid);
    if (!page)
    {
        cpp11::stop("Not a valid plot ID.");
    }

    return dev->api_remove(*page);
}

[[cpp11::register]]
cpp11::writable::list httpgd_id_(int devnum, int page, int limit)
{
    auto dev = validate_httpgddev(devnum);
    httpgd::HttpgdQueryResults res;
    
    if (page == -1)
    {
        res = dev->api_query_index(page);
    }
    else
    {
        res = dev->api_query_range(page, limit);
    }

    using namespace cpp11::literals;
    cpp11::writable::list state{
        "hsize"_nm = res.state.hsize,
        "upid"_nm = res.state.upid,
        "active"_nm = res.state.active};

    cpp11::writable::list plots{static_cast<R_xlen_t>(res.ids.size())};

    for (std::size_t i = 0; i < res.ids.size(); ++i)
    {
        cpp11::writable::list p{"id"_nm = std::to_string(res.ids[i])};
        p.attr("class") = "httpgd_pid";
        plots[i] = p;
    }

    return {
        "state"_nm = state,
        "plots"_nm = plots
    };
}

[[cpp11::register]]
bool httpgd_clear_(int devnum)
{
    auto dev = validate_httpgddev(devnum);
    return dev->api_clear();
}
