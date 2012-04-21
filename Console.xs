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


    public:
        static bool debug_mode;
        static void debug_log(string);

        static string last_error;
        static void set_last_error(string);

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
