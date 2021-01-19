#ifndef HTTPGD_DEV_H
#define HTTPGD_DEV_H

#include <cpp11/list.hpp>

#include <mutex>
#include <memory>
#include <iostream>
#include <boost/optional.hpp>

#include "devGeneric.h"
#include "HttpgdApi.h"
#include "HttpgdCommons.h"
#include "HttpgdDataStore.h"
#include "HttpgdApiAsync.h"
#include "HttpgdWebServer.h"

#include "PlotHistory.h"

namespace httpgd
{

    struct HttpgdDevStartParams
    {
        int bg;
        double width;
        double height;
        double pointsize;
        cpp11::list aliases;
        bool fix_strwidth;
    };

    class DeviceTarget
    {
    public:
        int get_index() const;
        void set_index(int index);
        int get_newest_index() const;
        void set_newest_index(int index);
        bool is_void() const;
        void set_void();

    private:
        int m_index{-1};        // current draw target
        int m_newest_index{-1}; // open draw target
        bool m_void{true};
    };

    class HttpgdDev : public devGeneric,
                      public HttpgdApi
    {
    public:

        // Font handling
        cpp11::list system_aliases;
        cpp11::list user_aliases;

        HttpgdDev(const HttpgdServerConfig &t_config, const HttpgdDevStartParams &t_params);
        virtual ~HttpgdDev();

        // http server
        bool server_start();
        void server_stop();
        unsigned short server_port() const;

        // API functions

        virtual void api_render(int index, double width, double height) override;
        virtual bool api_remove(int index) override;
        virtual bool api_clear() override;
        //virtual int api_upid() override;
        //virtual bool api_active() override;
        //virtual int api_page_count() override;
        virtual HttpgdState api_state() override;
        virtual void api_svg(std::ostream &os, int index, double width, double height) override;
        virtual std::shared_ptr<HttpgdServerConfig> api_server_config() override;

        // static 

        static std::string random_token(int len);

    protected:
        // Device callbacks

        virtual void dev_activate(pDevDesc dd) override;
        virtual void dev_deactivate(pDevDesc dd) override;
        virtual void dev_close(pDevDesc dd) override;
        virtual void dev_clip(double x0, double x1, double y0, double y1, pDevDesc dd) override;
        virtual void dev_size(double *left, double *right, double *bottom, double *top, pDevDesc dd) override;
        virtual void dev_newPage(pGEcontext gc, pDevDesc dd) override;
        virtual void dev_line(double x1, double y1, double x2, double y2, pGEcontext gc, pDevDesc dd) override;
        virtual void dev_text(double x, double y, const char *str, double rot, double hadj, pGEcontext gc, pDevDesc dd) override;
        virtual double dev_strWidth(const char *str, pGEcontext gc, pDevDesc dd) override;
        virtual void dev_rect(double x0, double y0, double x1, double y1, pGEcontext gc, pDevDesc dd) override;
        virtual void dev_circle(double x, double y, double r, pGEcontext gc, pDevDesc dd) override;
        virtual void dev_polygon(int n, double *x, double *y, pGEcontext gc, pDevDesc dd) override;
        virtual void dev_polyline(int n, double *x, double *y, pGEcontext gc, pDevDesc dd) override;
        virtual void dev_path(double *x, double *y, int npoly, int *nper, Rboolean winding, pGEcontext gc, pDevDesc dd) override;
        virtual void dev_mode(int mode, pDevDesc dd) override;
        virtual void dev_metricInfo(int c, pGEcontext gc, double *ascent, double *descent, double *width, pDevDesc dd) override;
        virtual void dev_raster(unsigned int *raster, int w, int h, double x, double y, double width, double height, double rot, Rboolean interpolate, pGEcontext gc, pDevDesc dd) override;

    private:
        PlotHistory m_history;
        std::shared_ptr<HttpgdServerConfig> m_svr_config;
        std::shared_ptr<HttpgdDataStore> m_data_store;
        std::shared_ptr<HttpgdApiAsync> m_api_async_watcher;
        
        std::shared_ptr<web::WebServer> m_server;

        bool replaying{false}; // Is the device replaying
        DeviceTarget m_target;

        bool m_initialized{false};
        bool m_server_running{false};

        void put(std::shared_ptr<dc::DrawCall> dc);

        // set device size
        void resize_device_to_page(pDevDesc dd);

        bool m_fix_strwidth  = true;
    };

} // namespace httpgd

#endif
