package com.katasticho.erp.common.country;

import lombok.RequiredArgsConstructor;
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.annotation.Before;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.aop.support.AopUtils;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;

/**
 * Enforces {@link RequiresCountry}. Byte-for-byte the same shape as
 * {@code ModuleAccessAspect}: a method-level annotation wins over a class-level
 * one, and the gate is checked before the method runs.
 */
@Aspect
@Component
@RequiredArgsConstructor
public class CountryAccessAspect {

    private final CountryAccessService countryAccessService;

    @Before("@within(com.katasticho.erp.common.country.RequiresCountry) "
            + "|| @annotation(com.katasticho.erp.common.country.RequiresCountry)")
    public void requireCountry(JoinPoint joinPoint) {
        RequiresCountry annotation = findAnnotation(joinPoint);
        if (annotation != null) {
            countryAccessService.requireCountry(annotation.value());
        }
    }

    private RequiresCountry findAnnotation(JoinPoint joinPoint) {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        Method method = signature.getMethod();
        RequiresCountry methodAnnotation =
                AnnotatedElementUtils.findMergedAnnotation(method, RequiresCountry.class);
        if (methodAnnotation != null) {
            return methodAnnotation;
        }
        Class<?> targetClass = AopUtils.getTargetClass(joinPoint.getTarget());
        return AnnotatedElementUtils.findMergedAnnotation(targetClass, RequiresCountry.class);
    }
}
