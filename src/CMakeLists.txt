set(SOURCES ais.c ais.c cfg.c crc32.c hlog.c input.c out_mysql.c receiver.c splay.c cache.c range.c cfgfile.c filter.c hmalloc.c out_json.c protodec.c rwlock.c serial.c spsymbol.c)

if(HAVE_PULSEAUDIO)
        set(SOURCES ${SOURCES} pulseaudio.c)
endif()
if(HAVE_AUDIOUNIT)
        set(SOURCES ${SOURCES} audiounit.c)
endif()
add_executable(gnuais ${SOURCES})

if(HAVE_AUDIOUNIT)
	FIND_LIBRARY(AUDIOUNIT_LIBRARY AudioUnit)
	MARK_AS_ADVANCED(AUDIOUNIT_LIBRARY)
	FIND_LIBRARY(COREAUDIO_LIBRARY CoreAudio)
	MARK_AS_ADVANCED(COREAUDIO_LIBRARY)
	target_link_libraries(gnuais ${AUDIOUNIT_LIBRARY} ${COREAUDIO_LIBRARY})
endif()

target_link_libraries(gnuais pthread m)

if(HAVE_MYSQL)
    target_link_libraries(gnuais mysqlclient)
else() 
    message(WARNING "You do not have development files for mysql. Mysql functionality will therefore be disabled")
endif()

if(HAVE_CURL)
    target_link_libraries(gnuais curl)
else()
    message(WARNING "You do not have the development files for curl. Functionaly using curl will therefore be disabled")
endif()

if(HAVE_ALSA)
    target_link_libraries(gnuais asound)
endif()

if(HAVE_PULSEAUDIO)
    target_link_libraries(gnuais pulse-simple)
else()
    message(WARNING "You do not have the development files for pulseaudio. Support for pulseaudio will therefore not be included")
endif()

install(TARGETS gnuais DESTINATION bin)

#if(HAVE_GTK)
add_subdirectory(gui)
#endif(HAVE_GTK)
