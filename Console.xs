#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#ifdef __cplusplus
}
#endif

#include <groonga/groonga.h>
#include <string>
#include <list>

#define DEBUG(msg) if ( Groonga::debug_mode ) { Groonga::debug_log(msg); }

using namespace std;

typedef list<string> strings;

class Groonga {
    private:
        static bool initialized;

        int context_flags;
        grn_ctx context;
        grn_obj *database;

        grn_logger_info simple_logger_info;
        grn_logger_info callback_logger_info;

    public:
        static bool debug_mode;
        static void debug_log(string);

        strings logs;
        static void simple_logger_func(int level, const char *time, const char *title,
                    const char *msg, const char *location, void *func_arg);

        CV *logger_callback;
        static void callback_logger_func(int level, const char *time, const char *title,
                    const char *msg, const char *location, void *func_arg);
        void set_logger(CV *, int flags);

        static string last_error;

        Groonga( string path, int context_flags = GRN_CTX_PER_DB ); /* GRN_CTX_BATCH_MODE ); */
        void destroy();
        ~Groonga();

        strings errors;
        void add_error(string, int rc = GRN_SUCCESS);
        void add_context_error();
        void clear_errors();

        bool is_connected();
        void console( strings &, strings & );
};

bool Groonga::debug_mode = FALSE;
void Groonga::debug_log( string message ) {
    if ( Groonga::debug_mode ) {
        fprintf( stderr, "[Groonga] %s\n", message.c_str() );
    }
}

bool Groonga::initialized = FALSE;
string Groonga::last_error;

void Groonga::simple_logger_func(int level, const char *time, const char *title,
                    const char *msg, const char *location, void *func_arg) {
    if ( msg ) {
        Groonga *me = (Groonga*)func_arg;
        me->logs.push_back(msg);
    }
}

void Groonga::callback_logger_func(int level, const char *time, const char *title,
                    const char *msg, const char *location, void *func_arg) {
    Groonga *me = (Groonga*)func_arg;
    CV* callback = me->logger_callback;

    {
        dSP;
        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        XPUSHs(sv_2mortal(newSViv(level)));

        if ( time )
            XPUSHs(sv_2mortal(newSVpv(time, string(time).length())));
        else
            XPUSHs(newSV(0));

        if ( title )
            XPUSHs(sv_2mortal(newSVpv(title, string(title).length())));
        else
            XPUSHs(newSV(0));

        if ( msg )
            XPUSHs(sv_2mortal(newSVpv(msg, string(msg).length())));
        else
            XPUSHs(newSV(0));

        if ( location )
            XPUSHs(sv_2mortal(newSVpv(location, string(location).length())));
        else
            XPUSHs(newSV(0));

        PUTBACK;

        call_sv((SV *)callback, G_VOID|G_DISCARD);

        FREETMPS;
        LEAVE;
    }
}

Groonga::Groonga( string path, int _context_flags ) {
    int rc;

    context_flags = _context_flags;
    database = NULL;

    // Initialize groonga if not.
    if ( !Groonga::initialized ) {
        DEBUG("Initializing");
        rc = grn_init();
        if ( rc != GRN_SUCCESS ) {
            Groonga::add_error("Failed to initialize", rc);
            return;
        }
        DEBUG("Initialized");
        Groonga::initialized = TRUE;
    }

    // Initialize context.
    DEBUG("Initializing context");
    grn_ctx_init( &context, context_flags );
    DEBUG("Initialized context");

    grn_logger_info logger_info = {
        GRN_LOG_DEFAULT_LEVEL,
        GRN_LOG_TIME|GRN_LOG_MESSAGE,
        Groonga::simple_logger_func,
        (void*)this
    };
    simple_logger_info = logger_info;
    grn_logger_info_set( &context, &simple_logger_info );

    logger_callback = NULL;

    if ( path.length() > 0 ) {
        // Open or create database.
        DEBUG("Opening database:" + path);
        database = grn_db_open(&context, path.c_str());
        if ( database == NULL ) {
            DEBUG("Creating new database:" + path);
            database = grn_db_create(&context, path.c_str(), NULL);
            if ( database == NULL ) {
                DEBUG("Failure to create database" + path);
                add_context_error();
                return;
            }
        }
        DEBUG("Opened or created database");
    } else {
        // On memory.
        DEBUG("Creating memory database");
        database = grn_db_create( &context, NULL, NULL );
        if ( database == NULL ) {
            DEBUG("Failure to create memory database");
            add_context_error();
            return;
        }
        DEBUG("Created memory database");
    }
}

void Groonga::set_logger(CV *cv, int flags) {
    if ( cv ) {
        logger_callback = cv;
        grn_logger_info logger_info = {
            GRN_LOG_DEFAULT_LEVEL,
            flags >= 0? flags: GRN_LOG_TIME|GRN_LOG_MESSAGE,
            Groonga::callback_logger_func,
            (void*)this
        };
        callback_logger_info = logger_info;
        grn_logger_info_set( &context, &callback_logger_info );
    } else {
        logger_callback = NULL;
        grn_logger_info_set( &context, &simple_logger_info );
    }
}

void Groonga::destroy() {
    // Free context.
    if ( database != NULL ) {
        DEBUG("Closing database");
        grn_obj_close(&context, database);
        database = NULL;
    }
    DEBUG("Finishing context");
    grn_ctx_fin(&context);
}

Groonga::~Groonga() {
    destroy();
}

void Groonga::add_error(string error, int rc) {
    // Add error to stack and set as the last error.
    if ( rc != GRN_SUCCESS ) {
        char buf[64];
        if ( 0 < sprintf(buf, "(rd:%d)", rc) )
            error += buf;
    }
    DEBUG("Adding global error:" + error);
    Groonga::last_error = error;
    errors.push_back(Groonga::last_error);
}

void Groonga::add_context_error() {
    // Add error from context to stack and set as the last error.
    string error = context.errbuf;
    if ( context.rc != GRN_SUCCESS ) {
        char buf[64];
        if ( 0 < sprintf(buf, "(rc:%d)", context.rc) )
            error += buf;
    }
    DEBUG("Adding context error:" + error);
    Groonga::last_error = error;
    errors.push_back(Groonga::last_error);
}

void Groonga::clear_errors() {
    // Clear errors stack.
    errors.clear();
}

bool Groonga::is_connected() {
    // Check if database opened.
    return database != NULL? TRUE: FALSE;
}

void Groonga::console( strings &input, strings &output ) {
    int rc;

    if ( !database ) {
        add_error( "Database not opened." );
        return;
    }

    for ( strings::iterator it = input.begin(), end = input.end(); it != end; it++ ) {
        // Split to lines because groonga accepts only a line for each time.
        string &str = *it;
        str += "\n";

        // Append line break.
        string::size_type start = 0;
        strings lines;
        for( string::size_type pos = str.find("\n"); pos != string::npos; pos = str.find("\n", pos + 1) ) {
            if ( pos == string::npos ) {
                // Last one.
                lines.push_back(str.substr(start));
                break;
            } else {
                // Continue to split.
                lines.push_back(str.substr(start, pos - start));
                start = pos + 1;
            }
        }

        // Send to groonga.
        for ( strings::iterator it = lines.begin(), end = lines.end(); it != end; it++ ) {
            // Skip empty line.
            string &line = *it;
            if ( line.length() < 1 ) continue;

            // Flush buffer.
            char *res;
            unsigned int len;
            int flags;
            rc = grn_ctx_recv(&context, &res, &len, &flags);
            while ( rc == GRN_SUCCESS && len > 0 ) {
                if ( Groonga::debug_mode ) {
                    string response(res, len);
                    DEBUG("Flush buffer:" + response);
                }
                rc = grn_ctx_recv(&context, &res, &len, &flags);
            }

            // Send command.
            DEBUG("Sending line:" + line);
            rc = grn_ctx_send(&context, line.c_str(), line.length(), context_flags);

            // Handle errors.
            if ( rc < 0 ) {
                add_error("Failured to send");
                continue;
            }
            if ( context.rc != GRN_SUCCESS ) {
                add_context_error();
                continue;
            }

            DEBUG("Sent line");

            // Try to receive result.
            DEBUG("Receiving result");
            rc = grn_ctx_recv(&context, &res, &len, &flags);
            if ( rc < 0 ) {
                add_error("Failured to receive");
                continue;
            }
            if ( context.rc != GRN_SUCCESS ) {
                add_context_error();
                continue;
            }

            while ( rc == GRN_SUCCESS && len > 0 ) {
                string result(res, len);
                output.push_back(result);
                DEBUG("Received result:" + result);
                rc = grn_ctx_recv(&context, &res, &len, &flags);
            }

        }
    }
}

MODULE = Groonga::Console		PACKAGE = Groonga::Console

static void
Groonga::set_debug_mode(sw)
    int sw
    CODE:
        Groonga::debug_mode = sw != 0? TRUE: FALSE;

static int
Groonga::get_debug_mode()
    CODE:
        RETVAL = Groonga::debug_mode? 1: 0;
    OUTPUT:
        RETVAL

void
Groonga::set_logger(CV* callback = NULL, int flags = 0)
    CODE:
        THIS->set_logger(callback, flags);

static SV *
Groonga::last_error()
    CODE:
        RETVAL = newSVpv( Groonga::last_error.c_str(), Groonga::last_error.length() );
    OUTPUT:
        RETVAL

PROTOTYPES: ENABLE

Groonga *
Groonga::new( path = NULL )
    char *path
    CODE:
        RETVAL = new Groonga( path != NULL? string(path): "" );
        if ( !RETVAL->is_connected() ) {
            delete RETVAL;
            XSRETURN_UNDEF;
        }
    OUTPUT:
        RETVAL

void
Groonga::DESTROY()

bool
Groonga::is_connected()

void
Groonga::add_error( error )
    char *error
    CODE:
        THIS->errors.push_back(string(error));

void
Groonga::errors()
    PPCODE:
        strings &errs = THIS->errors;
        for( strings::iterator it = errs.begin(), end = errs.end(); it != end; it++ ) {
            string &err = *it;
            XPUSHs(sv_2mortal(newSVpv( err.c_str(), err.length() )));
        }

void
Groonga::clear_errors()
    CODE:
        THIS->errors.clear();

void
Groonga::logs()
    PPCODE:
        strings &logs = THIS->logs;
        for( strings::iterator it = logs.begin(), end = logs.end(); it != end; it++ ) {
            string &log = *it;
            XPUSHs(sv_2mortal(newSVpv( log.c_str(), log.length() )));
        }

void
Groonga::clear_logs()
    CODE:
        THIS->logs.clear();

void
Groonga::console(...)
    PPCODE:
        strings input, output;
        for ( int i = 1; i < items; i++ ) {
            input.push_back((char*)SvPV_nolen(ST(i)));
        }
        THIS->console( input, output );
        for ( strings::iterator it = output.begin(), end = output.end(); it != end; it++ ) {
            string &result = *it;
            XPUSHs(sv_2mortal(newSVpv( result.c_str(), result.length() )));
        }

